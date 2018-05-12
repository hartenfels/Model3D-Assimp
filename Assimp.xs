#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <assimp/cimport.h>
#include <assimp/config.h>
#include <assimp/postprocess.h>
#include <assimp/scene.h>
#include <assimp/version.h>

typedef struct aiBone          aiBone;
typedef struct aiColor4D       aiColor4D;
typedef struct aiFace          aiFace;
typedef struct aiMatrix4x4     aiMatrix4x4;
typedef struct aiMesh          aiMesh;
typedef struct aiNode          aiNode;
typedef struct aiPropertyStore aiPropertyStore;
typedef struct aiScene         aiScene;
typedef struct aiString        aiString;
typedef struct aiVector3D      aiVector3D;
typedef struct aiVertexWeight  aiVertexWeight;


/*
 * The lifetime of nodes, meshes etc. is tied to the scene they came
 * from, so they need to keep track of their parent. I tried doing
 * this with the blessed object's SV refcount directly, but that's
 * not enough indirection, since you can obliterate the reference
 * by just assigning a different value to the variable in Perl.
 */

typedef struct SceneWrap {
    const aiScene *scene;
    int           refcnt;
} SceneWrap;

typedef struct Parented {
    void      *ptr;
    SceneWrap *parent;
} Parented;

/* For the typemap. */
typedef struct Parented ParentedBone;
typedef struct Parented ParentedNode;
typedef struct Parented ParentedMesh;

static inline SceneWrap *sw_new(const aiScene *scene)
{
    SceneWrap *sw;
    Newx(sw, sizeof(*sw), SceneWrap);
    sw->scene  = scene;
    sw->refcnt = 1;
    return sw;
}

static inline SceneWrap *sw_ref(SceneWrap *sw)
{
    ++sw->refcnt;
    return sw;
}

static inline SceneWrap *sw_unref(SceneWrap *sw)
{
    if (--sw->refcnt == 0) {
        aiReleaseImport(sw->scene);
        Safefree(sw);
    }
}


static void *unwrap_obj(const char *cls, SV *obj)
{
    if (sv_isa(obj, cls)) {
        SV *ref = SvRV(obj);
        IV iv   = SvIV(ref);
        return INT2PTR(void *, iv);
    }
    else {
        croak("'%s' is not a %s object", SvPV_nolen(obj), cls);
    }
}

static Parented *parented_new(void *ptr, SceneWrap *parent)
{
    Parented *parented;
    Newx(parented, sizeof(*parented), Parented);
    parented->ptr    = ptr;
    parented->parent = sw_ref(parent);
    return parented;
}

static void parented_destroy(Parented *parented)
{
    if (parented) {
        sw_unref(parented->parent);
        Safefree(parented);
    }
}


/*
 * Conversion to Perl data structures.
 *
 * I don't think most of these can sensibly go into the typemap because
 * they need to be stored in an AV, rather than being returned directly.
 *
 * There is the T_ARRAY output typemap thing that uses it somehow, but
 * it doesn't seem to generate the code I want.
 */

static SV *from_parented(const char *cls, void *ptr, SceneWrap *parent)
{
    SV *ref = newSV(0);
    if (ptr) {
        sv_setref_iv(ref, cls, PTR2IV(parented_new(ptr, parent)));
    }
    return ref;
}

#define SET_COLOR4D_CHANNEL(X) hv_stores(hv, #X, newSVnv(color->X))

static SV *from_ai_color4d(aiColor4D *color)
{
    if (color) {
        HV *hv = newHV();
        SET_COLOR4D_CHANNEL(a);
        SET_COLOR4D_CHANNEL(b);
        SET_COLOR4D_CHANNEL(g);
        SET_COLOR4D_CHANNEL(r);
        return newRV_noinc((SV *)hv);
    }
    else {
        return newSV(0);
    }
}

static SV *from_ai_face(aiFace *face)
{
    if (face) {
        AV *av = newAV();
        unsigned int i;
        for (i = 0; i < face->mNumIndices; ++i) {
            av_push(av, newSVuv(face->mIndices[i]));
        }
        return newRV_noinc((SV *)av);
    }
    else {
        return newSV(0);
    }
}

#define PUSH_MATRIX4X4_ROW(X) do { \
        AV *row = newAV(); \
        av_push(row, newSVnv(m->X ## 1)); \
        av_push(row, newSVnv(m->X ## 2)); \
        av_push(row, newSVnv(m->X ## 3)); \
        av_push(row, newSVnv(m->X ## 4)); \
        av_push(av, newRV_noinc((SV *)row)); \
    } while (0)

static SV *from_ai_matrix4x4(aiMatrix4x4 *m)
{
    if (m) {
        AV *av = newAV();
        PUSH_MATRIX4X4_ROW(a);
        PUSH_MATRIX4X4_ROW(b);
        PUSH_MATRIX4X4_ROW(c);
        PUSH_MATRIX4X4_ROW(d);
        return newRV_noinc((SV *)av);
    }
    else {
        return newSV(0);
    }
}

static SV *from_ai_vector3d_n(aiVector3D *vec, unsigned int n)
{
    if (n > 3) {
        warn("Can't get %u elements from a 3D vector (ignoring excess)", n);
        n = 3;
    }
    if (vec) {
        AV *av = newAV();
        av_extend(av, n);
        switch (n) {
            case 3:
                av_store(av, 2, newSVnv(vec->z));
            case 2:
                av_store(av, 1, newSVnv(vec->y));
            case 1:
                av_store(av, 0, newSVnv(vec->x));
            default:
                break;
        }
        return newRV_noinc((SV *)av);
    }
    else {
        return newSV(0);
    }
}

static SV *from_ai_vector3d(aiVector3D *vec)
{
    return from_ai_vector3d_n(vec, 3);
}

static SV *from_ai_vertex_weight(aiVertexWeight *vw)
{
    if (vw) {
        HV *hv = newHV();
        hv_stores(hv, "vertex_id", newSVuv(vw->mVertexId));
        hv_stores(hv, "weight",    newSVnv(vw->mWeight));
        return newRV_noinc((SV *)hv);
    }
    else  {
        return newSV(0);
    }
}


/*
 * Calling a Perl function from the Assimp logger.
 * I *think* I got the whole stack management correct anyway.
 */
static void logger_callback(const char *text, char *user)
{
    dSP;
    ENTER;
    SAVETMPS;

    SAVESPTR(GvSV(PL_defgv));
    GvSV(PL_defgv) = newSVpv(text, 0);

    PUSHMARK(SP);
    {
        SV *logger = (SV *)user;
        call_sv(logger, G_DISCARD | G_EVAL);
    }

    SPAGAIN;
    {
        SV *err = ERRSV;
        if (SvTRUE(err)) {
            const char *message = SvPV_nolen(err);
            warn("Assimp logger died: %s", message);
        }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;
}


/*
 * Slighty eerie macro to return an Assimp array member in a more
 * Perlish way. Assimp has a bunch of annoying X->mNumSomething and
 * X->mWhatever pairs in its structures. When you call X->whatever
 * in Perl, you get the num part in scalar context and the array
 * part in list context. This macro receives the upper bound and
 * a "callback" expression, which is tasked with converting a
 * single element to an SV, using the "i" variable as the index.
 *
 * Again, T_ARRAY in typemaps is a thing, but it doesn't really
 * do the same thing as this. It doesn't check GIMME_V for one.
 */
#define WRAP_ARRAY(TYPE, ARR, NUM, TO_SV) do { \
        TYPE *arr = ARR; \
        if (ARR) { \
            unsigned int len = NUM; \
            if (GIMME_V == G_ARRAY) { \
                unsigned int i; \
                EXTEND(SP, len); \
                for (i = 0; i < len; ++i) { \
                    TYPE *elem = &arr[i]; \
                    PUSHs(sv_2mortal(TO_SV)); \
                } \
            } \
            else { \
                XSRETURN_UV(len); \
            } \
        } \
    } while (0)


/*
 * Functions for wrapping *all* colors/texture coordinates.
 *
 * They essentially need to be double-wrapped, so that's done here. It
 * might be cleaner to just call our *own* XS function and wrap the
 * result into an arrayref, but calling Perl functions in XS is scary
 * and seems like it would be a whole lot longer.
 */

#define WRAP_ALL(TYPE, ARR, TO_SV) do { \
        if (ARR) { \
            AV *av = newAV(); \
            unsigned int i; \
            for (i = 0; i < length; ++i) { \
                TYPE elem = &ARR[i]; \
                SV   *sv  = TO_SV; \
                av_push(av, sv); \
            } \
        } \
        else { \
            return newSV(0); \
        } \
    } while (0)

static SV *wrap_all_colors(aiColor4D *colors, unsigned int length)
{
    WRAP_ALL(aiColor4D *, colors, from_ai_color4d(elem));
}

static SV *wrap_all_texture_coords(aiVector3D *uvs, unsigned int length,
                                   unsigned int components)
{
    WRAP_ALL(aiVector3D *, uvs, from_ai_vector3d_n(elem, components));
}


#define CHECK_INDEX(INDEX, MAX, NAME) do { \
        unsigned int _idx = (INDEX), _max = (MAX); \
        if (_idx >= _max) { \
            croak(NAME " index %u beyond maximum %u", _idx, _max); \
        } \
    } while (0)

#define CHECK_COLOR_SET_INDEX(INDEX) \
    CHECK_INDEX(INDEX, AI_MAX_NUMBER_OF_COLOR_SETS, "Color set")

#define CHECK_TEXTURE_COORDINATE_INDEX(INDEX) \
    CHECK_INDEX(INDEX, AI_MAX_NUMBER_OF_TEXTURECOORDS, "Texture coordinate")


void matrix4x4_from_euler_angles(aiMatrix4x4 *m, float x, float y, float z)
{
    float cr   = cosf(x);
    float sr   = sinf(x);
    float cp   = cosf(y);
    float sp   = sinf(y);
    float cy   = cosf(z);
    float sy   = sinf(z);
    float srsp = sr * sp;
    float crsp = cr * sp;

    m->a1 = cp * cy;
    m->a2 = cp * sy;
    m->a3 = -sp;

    m->b1 = srsp * cy - cr * sy;
    m->b2 = srsp * sy + cr * cy;
    m->b3 = sr * cp;

    m->c1 = crsp * cy + sr * sy;
    m->c2 = crsp * sy - sr * cy;
    m->c3 = cr * cp;
}

void correct_vec3d(aiMatrix4x4 *m, aiVector3D *vec)
{
    float x = vec->x, y = vec->y, z = vec->z;
    vec->x = m->a1 * x + m->a2 * y + m->a3 * z + m->a4;
    vec->y = m->b1 * x + m->b2 * y + m->b3 * z + m->b4;
    vec->z = m->c1 * x + m->c2 * y + m->c3 * z + m->c4;
}

void correct_vec3ds(aiMatrix4x4 *m, unsigned int num, aiVector3D *vecs)
{
    if (vecs) {
        unsigned int i;
        for (i = 0; i < num; ++i) {
            correct_vec3d(m, &vecs[i]);
        }
    }
}

void correct_mesh(aiMatrix4x4 *m, aiMesh *mesh)
{
    correct_vec3ds(m, mesh->mNumVertices, mesh->mVertices);
    correct_vec3ds(m, mesh->mNumVertices, mesh->mNormals);
}

void correct_meshes(aiMatrix4x4 *m, unsigned int num, aiMesh **meshes)
{
    if (meshes) {
        unsigned int i;
        for (i = 0; i < num; ++i) {
            correct_mesh(m, meshes[i]);
        }
    }
}


#define PKG_PREFIX     "Model3D::Assimp::"
#define PKG_XS         PKG_PREFIX "XS"
#define PKG_BONE       PKG_PREFIX "Bone"
#define PKG_MESH       PKG_PREFIX "Mesh"
#define PKG_NODE       PKG_PREFIX "Node"
#define PKG_PROPERTIES PKG_PREFIX "Properties"
#define PKG_SCENE      PKG_PREFIX "Scene"


/*
 * I don't want to inject all these XS functions into all the various
 * packages, because then you wouldn't be able to see what's actually
 * defined in a package by looking at its file. So instead, I put them
 * all in the ::XS package and do a manual import in each package.
 */
MODULE = Model3D::Assimp    PACKAGE = Model3D::Assimp::XS

PROTOTYPES: DISABLE


unsigned int
component_colors(unsigned int n)
    CODE:
        RETVAL = aiComponent_COLORSn(n);
    OUTPUT:
        RETVAL

unsigned int
component_textures(unsigned int n)
    CODE:
        RETVAL = aiComponent_TEXCOORDSn(n);
    OUTPUT:
        RETVAL


aiPropertyStore *
aiCreatePropertyStore(...)

void
aiReleasePropertyStore(aiPropertyStore *self, ...)

void
aiSetImportPropertyInteger(aiPropertyStore *self, const char *key, int value)

void
aiSetImportPropertyFloat(aiPropertyStore *self, const char *key, float value)

void
aiSetImportPropertyString(aiPropertyStore *self, const char *key, aiString value)
    CODE:
        aiSetImportPropertyString(self, key, &value);


void
logger_set(SV *logger)
    PREINIT:
        /* There can be only one log stream. */
        static struct aiLogStream log_stream = {NULL, NULL};
    CODE:
        /* Remove the previous logger if it existed... */
        aiDetachLogStream(&log_stream);
        if (log_stream.user) {
            SV *logger = (SV *)log_stream.user;
            SvREFCNT_dec(logger);
        }
        log_stream.callback = NULL;
        log_stream.user     = NULL;
        /* ... and attach the new one if it was given. */
        if (SvOK(logger)) {
            SvREFCNT_inc(logger);
            log_stream.callback = logger_callback;
            log_stream.user     = (char *)logger;
            aiAttachLogStream(&log_stream);
        }

void
aiEnableVerboseLogging(bool verbose)


SceneWrap *
aiImportFileExWithProperties(const char      *cls,    \
                             const char      *path,   \
                             unsigned int    ppflags, \
                             aiPropertyStore *props)
    PREINIT:
        const aiScene *scene;
    CODE:
        scene = aiImportFileExWithProperties(path, ppflags, NULL, props);
        if (!scene) {
            croak("Can't load scene '%s': %s", path, aiGetErrorString());
        }
        RETVAL = sw_new(scene);
    OUTPUT:
        RETVAL

void
scene_destroy(SceneWrap *self, ...)
    CODE:
        sw_unref(self);

unsigned int
scene_flags(const aiScene *self)
    CODE:
        RETVAL = self->mFlags;
    OUTPUT:
        RETVAL

void
scene_meshes(SceneWrap *self)
    PPCODE:
        WRAP_ARRAY(aiMesh *, self->scene->mMeshes, self->scene->mNumMeshes,
                   from_parented(PKG_MESH, *elem, self));

aiNode *
scene_root_node(SceneWrap *parent)
    CODE:
        RETVAL = parent->scene->mRootNode;
    OUTPUT:
        RETVAL

void
scene_rotate(const aiScene *self, float x, float y, float z)
    PREINIT:
        aiMatrix4x4 m;
    CODE:
        matrix4x4_from_euler_angles(&m, x, y, z);
        correct_meshes(&m, self->mNumMeshes, self->mMeshes);


bool
aiApplyPostProcessing(const aiScene *self, unsigned int ppflags)
    CODE:
        RETVAL = !!aiApplyPostProcessing(self, ppflags);
    OUTPUT:
        RETVAL

void
node_destroy(ParentedNode *self)
    CODE:
        parented_destroy(self);

aiString *
node_name(aiNode *self)
    CODE:
        RETVAL = &self->mName;
    OUTPUT:
        RETVAL

aiNode *
node_parent(ParentedNode *self)
    PREINIT:
        SceneWrap *parent;
    CODE:
        parent = self->parent;
        RETVAL = ((aiNode *)self->ptr)->mParent;
    OUTPUT:
        RETVAL

void
node_children(ParentedNode *self)
    PREINIT:
        aiNode *node;
    PPCODE:
        node = (aiNode *)self->ptr;
        WRAP_ARRAY(aiNode *, node->mChildren, node->mNumChildren,
                   from_parented(PKG_NODE, *elem, self->parent));

void
node_meshes(aiNode *self)
    PPCODE:
        WRAP_ARRAY(unsigned int, self->mMeshes, self->mNumMeshes,
                   newSVuv(*elem));

aiMatrix4x4 *
node_transformation(aiNode *self)
    CODE:
        RETVAL = &self->mTransformation;
    OUTPUT:
        RETVAL


void
mesh_destroy(ParentedMesh *self)
    CODE:
        parented_destroy(self);

aiString *
mesh_name(aiMesh *self)
    CODE:
        RETVAL = &self->mName;
    OUTPUT:
        RETVAL

unsigned int
mesh_material_index(aiMesh *self)
    CODE:
        RETVAL = self->mMaterialIndex;
    OUTPUT:
        RETVAL

unsigned int
mesh_primitive_types(aiMesh *self)
    CODE:
        RETVAL = self->mPrimitiveTypes;
    OUTPUT:
        RETVAL

void
mesh_bitangents(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiVector3D, self->mBitangents, self->mNumVertices,
                   from_ai_vector3d(elem));

void
mesh_bones(ParentedMesh *self)
    PREINIT:
        aiMesh *mesh;
    PPCODE:
        mesh = (aiMesh *)self->ptr;
        WRAP_ARRAY(aiBone *, mesh->mBones, mesh->mNumBones,
                   from_parented(PKG_BONE, *elem, self->parent));

void
mesh_colors(aiMesh *self, unsigned int index)
    PPCODE:
        CHECK_COLOR_SET_INDEX(index);
        WRAP_ARRAY(aiColor4D, self->mColors[index], self->mNumVertices,
                   from_ai_color4d(elem));

void
mesh_all_colors(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiColor4D *, self->mColors, AI_MAX_NUMBER_OF_COLOR_SETS,
                   wrap_all_colors(*elem, self->mNumVertices));

void
mesh_faces(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiFace, self->mFaces, self->mNumFaces, from_ai_face(elem));

void
mesh_normals(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiVector3D, self->mNormals, self->mNumVertices,
                   from_ai_vector3d(elem));

void
mesh_tangents(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiVector3D, self->mTangents, self->mNumVertices,
                   from_ai_vector3d(elem));

void
mesh_vertices(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiVector3D, self->mVertices, self->mNumVertices,
                   from_ai_vector3d(elem));

void
mesh_texture_coords(aiMesh *self, unsigned int index)
    PREINIT:
        unsigned int components;
    PPCODE:
        CHECK_TEXTURE_COORDINATE_INDEX(index);
        components = self->mNumUVComponents[index];
        WRAP_ARRAY(aiVector3D, self->mTextureCoords[index], self->mNumVertices,
                   from_ai_vector3d_n(elem, components));

void
mesh_all_texture_coords(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(aiVector3D *, self->mTextureCoords,
                   AI_MAX_NUMBER_OF_TEXTURECOORDS,
                   wrap_all_texture_coords(*elem, self->mNumVertices,
                                           self->mNumUVComponents[i]));

unsigned int
mesh_num_uv_components(aiMesh *self, unsigned int index)
    CODE:
        CHECK_TEXTURE_COORDINATE_INDEX(index);
        RETVAL = self->mNumUVComponents[index];
    OUTPUT:
        RETVAL

void
mesh_all_num_uv_components(aiMesh *self)
    PPCODE:
        WRAP_ARRAY(unsigned int, self->mNumUVComponents,
                   AI_MAX_NUMBER_OF_TEXTURECOORDS, newSVuv(*elem));

void
mesh_rotate(aiMesh *self, float x, float y, float z)
    PREINIT:
        aiMatrix4x4 matrix;
    CODE:
        matrix4x4_from_euler_angles(&matrix, x, y, z);
        correct_mesh(&matrix, self);


void
bone_destroy(ParentedBone *self)
    CODE:
        parented_destroy(self);

aiString *
bone_name(aiBone *self)
    CODE:
        RETVAL = &self->mName;
    OUTPUT:
        RETVAL

aiMatrix4x4 *
bone_offset_matrix(aiBone *self)
    CODE:
        RETVAL = &self->mOffsetMatrix;
    OUTPUT:
        RETVAL

void
bone_weights(aiBone *self)
    PPCODE:
        WRAP_ARRAY(aiVertexWeight, self->mWeights, self->mNumWeights,
                   from_ai_vertex_weight(elem));

BOOT:
{
    /* Prepare yourself for a boatload of constants. */
    HV* stash = gv_stashpv(PKG_XS, GV_ADD);
    /* I guess the library version may come in handy. */
    newCONSTSUB(stash, "AI_VERSION", newSVpvf("%u.%u.%u",
        aiGetVersionMajor(), aiGetVersionMinor(), aiGetVersionRevision()));
    /* Let's not repeat the name and the value on each line. */
#   define IVCONST(NAME) newCONSTSUB(stash, #NAME, newSViv(NAME))
#   define UVCONST(NAME) newCONSTSUB(stash, #NAME, newSVuv(NAME))
#   define NVCONST(NAME) newCONSTSUB(stash, #NAME, newSVnv(NAME))
#   define PVCONST(NAME) newCONSTSUB(stash, #NAME, newSVpvs(NAME))
    /* Configuration keys */
    PVCONST(AI_CONFIG_FAVOUR_SPEED);
    PVCONST(AI_CONFIG_GLOB_MEASURE_TIME);
    PVCONST(AI_CONFIG_IMPORT_AC_EVAL_SUBDIVISION);
    PVCONST(AI_CONFIG_IMPORT_AC_SEPARATE_BFCULL);
    PVCONST(AI_CONFIG_IMPORT_ASE_RECONSTRUCT_NORMALS);
    PVCONST(AI_CONFIG_IMPORT_GLOBAL_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_IFC_CUSTOM_TRIANGULATION);
    PVCONST(AI_CONFIG_IMPORT_IFC_SKIP_CURVE_REPRESENTATIONS);
    PVCONST(AI_CONFIG_IMPORT_IFC_SKIP_SPACE_REPRESENTATIONS);
    PVCONST(AI_CONFIG_IMPORT_IRR_ANIM_FPS);
    PVCONST(AI_CONFIG_IMPORT_LWO_ONE_LAYER_ONLY);
    PVCONST(AI_CONFIG_IMPORT_LWS_ANIM_END);
    PVCONST(AI_CONFIG_IMPORT_LWS_ANIM_START);
    PVCONST(AI_CONFIG_IMPORT_MD2_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_MD3_HANDLE_MULTIPART);
    PVCONST(AI_CONFIG_IMPORT_MD3_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_MD3_SHADER_SRC);
    PVCONST(AI_CONFIG_IMPORT_MD3_SKIN_NAME);
    PVCONST(AI_CONFIG_IMPORT_MD5_NO_ANIM_AUTOLOAD);
    PVCONST(AI_CONFIG_IMPORT_MDC_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_MDL_COLORMAP);
    PVCONST(AI_CONFIG_IMPORT_MDL_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_OGRE_MATERIAL_FILE);
    PVCONST(AI_CONFIG_IMPORT_OGRE_TEXTURETYPE_FROM_FILENAME);
    PVCONST(AI_CONFIG_IMPORT_SMD_KEYFRAME);
    PVCONST(AI_CONFIG_IMPORT_TER_MAKE_UVS);
    PVCONST(AI_CONFIG_IMPORT_UNREAL_HANDLE_FLAGS);
    PVCONST(AI_CONFIG_IMPORT_UNREAL_KEYFRAME);
    PVCONST(AI_CONFIG_PP_CT_MAX_SMOOTHING_ANGLE);
    PVCONST(AI_CONFIG_PP_CT_TEXTURE_CHANNEL_INDEX);
    PVCONST(AI_CONFIG_PP_DB_ALL_OR_NONE);
    PVCONST(AI_CONFIG_PP_DB_THRESHOLD);
    PVCONST(AI_CONFIG_PP_FD_REMOVE);
    PVCONST(AI_CONFIG_PP_FID_ANIM_ACCURACY);
    PVCONST(AI_CONFIG_PP_GSN_MAX_SMOOTHING_ANGLE);
    PVCONST(AI_CONFIG_PP_ICL_PTCACHE_SIZE);
    PVCONST(AI_CONFIG_PP_LBW_MAX_WEIGHTS);
    PVCONST(AI_CONFIG_PP_OG_EXCLUDE_LIST);
    PVCONST(AI_CONFIG_PP_PTV_KEEP_HIERARCHY);
    PVCONST(AI_CONFIG_PP_PTV_NORMALIZE);
    PVCONST(AI_CONFIG_PP_RRM_EXCLUDE_LIST);
    PVCONST(AI_CONFIG_PP_RVC_FLAGS);
    PVCONST(AI_CONFIG_PP_SBBC_MAX_BONES);
    PVCONST(AI_CONFIG_PP_SBP_REMOVE);
    PVCONST(AI_CONFIG_PP_SLM_TRIANGLE_LIMIT);
    PVCONST(AI_CONFIG_PP_SLM_VERTEX_LIMIT);
    PVCONST(AI_CONFIG_PP_TUV_EVALUATE);
    /* Post-processing default values. */
    NVCONST(AI_DEBONE_THRESHOLD);
    IVCONST(AI_LMW_MAX_WEIGHTS);
    IVCONST(AI_SBBC_DEFAULT_MAX_BONES);
    IVCONST(AI_SLM_DEFAULT_MAX_TRIANGLES);
    IVCONST(AI_SLM_DEFAULT_MAX_VERTICES);
    /* Flags for UV coordinate transformation. */
    IVCONST(AI_UVTRAFO_ALL);
    IVCONST(AI_UVTRAFO_ROTATION);
    IVCONST(AI_UVTRAFO_SCALING);
    IVCONST(AI_UVTRAFO_TRANSLATION);
    /* Component flags for removing the unneded ones. */
    IVCONST(aiComponent_NORMALS);
    IVCONST(aiComponent_TANGENTS_AND_BITANGENTS);
    IVCONST(aiComponent_COLORS);
    IVCONST(aiComponent_TEXCOORDS);
    IVCONST(aiComponent_BONEWEIGHTS);
    IVCONST(aiComponent_ANIMATIONS);
    IVCONST(aiComponent_TEXTURES);
    IVCONST(aiComponent_LIGHTS);
    IVCONST(aiComponent_CAMERAS);
    IVCONST(aiComponent_MESHES);
    IVCONST(aiComponent_MATERIALS);
    /* Primitive type flags, so you can remove everything but triangles. */
    IVCONST(aiPrimitiveType_POINT);
    IVCONST(aiPrimitiveType_LINE);
    IVCONST(aiPrimitiveType_TRIANGLE);
    IVCONST(aiPrimitiveType_POLYGON);
    /* Post-processing flags. */
    IVCONST(aiProcess_ConvertToLeftHanded);
    IVCONST(aiProcessPreset_TargetRealtime_Fast);
    IVCONST(aiProcessPreset_TargetRealtime_MaxQuality);
    IVCONST(aiProcessPreset_TargetRealtime_Quality);
    IVCONST(aiProcess_CalcTangentSpace);
    IVCONST(aiProcess_JoinIdenticalVertices);
    IVCONST(aiProcess_MakeLeftHanded);
    IVCONST(aiProcess_Triangulate);
    IVCONST(aiProcess_RemoveComponent);
    IVCONST(aiProcess_GenNormals);
    IVCONST(aiProcess_GenSmoothNormals);
    IVCONST(aiProcess_SplitLargeMeshes);
    IVCONST(aiProcess_PreTransformVertices);
    IVCONST(aiProcess_LimitBoneWeights);
    IVCONST(aiProcess_ValidateDataStructure);
    IVCONST(aiProcess_ImproveCacheLocality);
    IVCONST(aiProcess_RemoveRedundantMaterials);
    IVCONST(aiProcess_FixInfacingNormals);
    IVCONST(aiProcess_SortByPType);
    IVCONST(aiProcess_FindDegenerates);
    IVCONST(aiProcess_FindInvalidData);
    IVCONST(aiProcess_GenUVCoords);
    IVCONST(aiProcess_TransformUVCoords);
    IVCONST(aiProcess_FindInstances);
    IVCONST(aiProcess_OptimizeMeshes);
    IVCONST(aiProcess_OptimizeGraph);
    IVCONST(aiProcess_FlipUVs);
    IVCONST(aiProcess_FlipWindingOrder);
    IVCONST(aiProcess_SplitByBoneCount);
    IVCONST(aiProcess_Debone);
    /* Scene flags, in case you want to check for INCOMPLETE I guess. */
    IVCONST(AI_SCENE_FLAGS_INCOMPLETE);
    IVCONST(AI_SCENE_FLAGS_VALIDATED);
    IVCONST(AI_SCENE_FLAGS_VALIDATION_WARNING);
    IVCONST(AI_SCENE_FLAGS_NON_VERBOSE_FORMAT);
    IVCONST(AI_SCENE_FLAGS_TERRAIN);
    /* Scene limits. */
    UVCONST(AI_MAX_NUMBER_OF_COLOR_SETS);
    UVCONST(AI_MAX_NUMBER_OF_TEXTURECOORDS);
}
