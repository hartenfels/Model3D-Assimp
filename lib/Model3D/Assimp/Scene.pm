package Model3D::Assimp::Scene;

# ABSTRACT: Assimp scene
use strict;
use warnings;
use Carp qw(croak);
use Math::Trig qw(deg2rad);
use Model3D::Assimp::XS qw(:constants);
use Model3D::Assimp::Mesh;
use Model3D::Assimp::Node;
use Model3D::Assimp::Animation;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        new        aiImportFileExWithProperties
        DESTROY    scene_destroy
        flags      scene_flags
        meshes     scene_meshes
        root_node  scene_root_node
        animations scene_animations
    );
}


sub set_logger {
    goto &Model3D::Assimp::set_logger;
}

sub set_verbose {
    goto &Model3D::Assimp::set_verbose;
}


sub _apply_pp {
    my ($self, $ppflags) = @_;
    if (!Model3D::Assimp::XS::aiApplyPostProcessing($self, $ppflags)) {
        croak("Post-processing error");
    }
    return $self;
}

sub apply_calc_tangent_space {
    return shift->_apply_pp(aiProcess_CalcTangentSpace);
}

sub apply_join_identical_vertices {
    return shift->_apply_pp(aiProcess_JoinIdenticalVertices);
}

sub apply_make_left_handed {
    return shift->_apply_pp(aiProcess_MakeLeftHanded);
}

sub apply_triangulate {
    return shift->_apply_pp(aiProcess_Triangulate);
}

sub apply_remove_component {
    return shift->_apply_pp(aiProcess_RemoveComponent);
}

sub apply_gen_normals {
    return shift->_apply_pp(aiProcess_GenNormals);
}

sub apply_gen_smooth_normals {
    return shift->_apply_pp(aiProcess_GenSmoothNormals);
}

sub apply_split_large_meshes {
    return shift->_apply_pp(aiProcess_SplitLargeMeshes);
}

sub apply_pre_transform_vertices {
    return shift->_apply_pp(aiProcess_PreTransformVertices);
}

sub apply_limit_bone_weights {
    return shift->_apply_pp(aiProcess_LimitBoneWeights);
}

sub apply_validate_data_structure {
    return shift->_apply_pp(aiProcess_ValidateDataStructure);
}

sub apply_improve_cache_locality {
    return shift->_apply_pp(aiProcess_ImproveCacheLocality);
}

sub apply_remove_redundant_materials {
    return shift->_apply_pp(aiProcess_RemoveRedundantMaterials);
}

sub apply_fix_infacing_normals {
    return shift->_apply_pp(aiProcess_FixInfacingNormals);
}

sub apply_sort_by_ptype {
    return shift->_apply_pp(aiProcess_SortByPType);
}

sub apply_find_degenerates {
    return shift->_apply_pp(aiProcess_FindDegenerates);
}

sub apply_find_invalid_data {
    return shift->_apply_pp(aiProcess_FindInvalidData);
}

sub apply_gen_uv_coords {
    return shift->_apply_pp(aiProcess_GenUVCoords);
}

sub apply_transform_uv_coords {
    return shift->_apply_pp(aiProcess_TransformUVCoords);
}

sub apply_find_instances {
    return shift->_apply_pp(aiProcess_FindInstances);
}

sub apply_optimize_meshes {
    return shift->_apply_pp(aiProcess_OptimizeMeshes);
}

sub apply_optimize_graph {
    return shift->_apply_pp(aiProcess_OptimizeGraph);
}

sub apply_flip_uvs {
    return shift->_apply_pp(aiProcess_FlipUVs);
}

sub apply_flip_winding_order {
    return shift->_apply_pp(aiProcess_FlipWindingOrder);
}

sub apply_split_by_bone_count {
    return shift->_apply_pp(aiProcess_SplitByBoneCount);
}

sub apply_debone {
    return shift->_apply_pp(aiProcess_Debone);
}


sub rotate_rad {
    my ($self, @args) = @_;
    Model3D::Assimp::XS::scene_rotate($self, @args);
    return $self;
}

sub rotate_deg {
    my ($self, @args) = @_;
    return $self->rotate_rad(map { deg2rad($_) } @args);
}


1;
