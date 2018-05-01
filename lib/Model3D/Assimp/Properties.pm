package Model3D::Assimp::Properties;

# ABSTRACT: Assimp Properties
use strict;
use warnings;
use Carp qw(croak);
use List::Util qw(pairs);
use Model3D::Assimp::XS qw(:constants);

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        new         aiCreatePropertyStore
        DESTROY     aiReleasePropertyStore
        _set_int    aiSetImportPropertyInteger
        _set_float  aiSetImportPropertyFloat
        _set_string aiSetImportPropertyString
    );
}

our %PROPERTIES = (
    AI_CONFIG_FAVOUR_SPEED, 'int',
    AI_CONFIG_GLOB_MEASURE_TIME, 'bool',
    AI_CONFIG_IMPORT_AC_EVAL_SUBDIVISION, 'bool',
    AI_CONFIG_IMPORT_AC_SEPARATE_BFCULL, 'bool',
    AI_CONFIG_IMPORT_ASE_RECONSTRUCT_NORMALS, 'bool',
    AI_CONFIG_IMPORT_GLOBAL_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_IFC_CUSTOM_TRIANGULATION, 'bool',
    AI_CONFIG_IMPORT_IFC_SKIP_CURVE_REPRESENTATIONS, 'bool',
    AI_CONFIG_IMPORT_IFC_SKIP_SPACE_REPRESENTATIONS, 'bool',
    AI_CONFIG_IMPORT_IRR_ANIM_FPS, 'int',
    AI_CONFIG_IMPORT_LWO_ONE_LAYER_ONLY, 'int',
    AI_CONFIG_IMPORT_LWS_ANIM_END, 'int',
    AI_CONFIG_IMPORT_LWS_ANIM_START, 'int',
    AI_CONFIG_IMPORT_MD2_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_MD3_HANDLE_MULTIPART, 'bool',
    AI_CONFIG_IMPORT_MD3_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_MD3_SHADER_SRC, 'string',
    AI_CONFIG_IMPORT_MD3_SKIN_NAME, 'string',
    AI_CONFIG_IMPORT_MD5_NO_ANIM_AUTOLOAD, 'bool',
    AI_CONFIG_IMPORT_MDC_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_MDL_COLORMAP, 'bool',
    AI_CONFIG_IMPORT_MDL_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_OGRE_MATERIAL_FILE, 'string',
    AI_CONFIG_IMPORT_OGRE_TEXTURETYPE_FROM_FILENAME, 'bool',
    AI_CONFIG_IMPORT_SMD_KEYFRAME, 'int',
    AI_CONFIG_IMPORT_TER_MAKE_UVS, 'bool',
    AI_CONFIG_IMPORT_UNREAL_HANDLE_FLAGS, 'bool',
    AI_CONFIG_IMPORT_UNREAL_KEYFRAME, 'int',
    AI_CONFIG_PP_CT_MAX_SMOOTHING_ANGLE, 'float',
    AI_CONFIG_PP_CT_TEXTURE_CHANNEL_INDEX, 'int',
    AI_CONFIG_PP_DB_ALL_OR_NONE, 'bool',
    AI_CONFIG_PP_DB_THRESHOLD, 'float',
    AI_CONFIG_PP_FD_REMOVE, 'bool',
    AI_CONFIG_PP_FID_ANIM_ACCURACY, 'float',
    AI_CONFIG_PP_GSN_MAX_SMOOTHING_ANGLE, 'float',
    AI_CONFIG_PP_ICL_PTCACHE_SIZE, 'int',
    AI_CONFIG_PP_LBW_MAX_WEIGHTS, 'int',
    AI_CONFIG_PP_OG_EXCLUDE_LIST, 'string',
    AI_CONFIG_PP_PTV_KEEP_HIERARCHY, 'bool',
    AI_CONFIG_PP_PTV_NORMALIZE, 'bool',
    AI_CONFIG_PP_RRM_EXCLUDE_LIST, 'string',
    AI_CONFIG_PP_RVC_FLAGS, 'int',
    AI_CONFIG_PP_SBBC_MAX_BONES, 'int',
    AI_CONFIG_PP_SBP_REMOVE, 'int',
    AI_CONFIG_PP_SLM_TRIANGLE_LIMIT, 'int',
    AI_CONFIG_PP_SLM_VERTEX_LIMIT, 'int',
    AI_CONFIG_PP_TUV_EVALUATE, 'int',
);

sub _set_bool {
    my ($self, $key, $value) = @_;
    return $self->_set_int($key, $value ? 1 : 0);
}

sub _set_single {
    my ($self, $key, $value) = @_;
    my $type   = $PROPERTIES{$key} or croak "Property not found: '$key'";
    my $method = "_set_$type";
    $self->$method($key, $value);
}

sub set {
    my ($self, @kvlist) = @_;
    for my $pair (pairs @kvlist) {
        $self->_set_single(@$pair);
    }
    return $self;
}


1;
