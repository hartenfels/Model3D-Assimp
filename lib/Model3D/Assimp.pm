package Model3D::Assimp;

# ABSTRACT: Assimp
use strict;
use warnings;
use Carp qw(croak);
use List::Util qw(reduce);
use Model3D::Assimp::XS qw(:constants);
use Model3D::Assimp::Properties;
use Model3D::Assimp::Scene;


sub new {
    my ($class) = @_;
    return bless {
        _ppflags => 0,
        _props   => Model3D::Assimp::Properties->new,
    }, $class;
}


sub set_logger {
    my ($invocant, $logger) = @_;
    Model3D::Assimp::XS::logger_set($logger);
    return $invocant;
}

sub set_verbose {
    my $invocant = shift;
    my $verbose  = @_ ? shift : 1;
    Model3D::Assimp::XS::aiEnableVerboseLogging($verbose);
    return $invocant;
}


{
    my $prefix = 'AI_CONFIG_PP_';
    for my $constant (grep { /^$prefix/ } sort keys %Model3D::Assimp::XS::) {
        my $name = lc substr $constant, length $prefix;
        eval qq/
            sub $name {
                my (\$self, \$value) = \@_;
                \$self->{_props}->set($constant, \$value) if defined \$value;
                return \$self;
            }
        /;
    }
}


sub _mkflags {
    my ($prefix) = @_;
    return map {
        my $key   = lc substr $_, length $prefix;
        my $value = $Model3D::Assimp::XS::{$_}->();
        ($key => $value)
    } grep { /^$prefix/ } sort keys %Model3D::Assimp::XS::;
}

our %COMPONENTS      = _mkflags('aiComponent_');
our %PRIMITIVE_TYPES = _mkflags('aiPrimitiveType_');

sub _to_component_flag {
    my $key = shift // '';
    if ($key =~ /^colors([0-9]+)$/) {
        return Model3D::Assimp::XS::component_colors($1);
    }
    elsif ($key =~ /^texcoords([0-9]+)$/) {
        return Model3D::Assimp::XS::component_texcoords($1);
    }
    else {
        return $COMPONENTS{$key} || croak "No such component: '$key'";
    }
}

sub _to_primitive_type_flag {
    my $key = shift // '';
    return $PRIMITIVE_TYPES{$key} || croak "No such primitive type: '$key'";
}


sub _flags {
    return reduce { $a | $b } @_, 0;
}

sub rvc_components {
    return shift->rvc_flags(_flags(map { _to_component_flag($_) } @_));
}

sub sbp_remove_types {
    return shift->sbp_remove(_flags(map { _to_primitive_type_flag($_) } @_));
}

sub _pp {
    my ($self, @flags) = @_;
    $self->{_ppflags} |= _flags(@flags);
    return $self;
}


sub calc_tangent_space {
    return shift->_pp(aiProcess_CalcTangentSpace)
                ->ct_max_smoothing_angle(shift);
}

sub join_identical_vertices {
    return shift->_pp(aiProcess_JoinIdenticalVertices);
}

sub make_left_handed {
    return shift->_pp(aiProcess_MakeLeftHanded);
}

sub triangulate {
    return shift->_pp(aiProcess_Triangulate);
}

sub remove_component {
    my ($self, @components) = @_;
    return $self->_pp(aiProcess_RemoveComponent)
                ->rvc_components(@components);
}

sub gen_normals {
    return shift->_pp(aiProcess_GenNormals);
}

sub gen_smooth_normals {
    return shift->_pp(aiProcess_GenSmoothNormals)
                ->gsn_max_smoothing_angle(shift);
}

sub split_large_meshes {
    return shift->_pp(aiProcess_SplitLargeMeshes)
                ->slm_triangle_limit(shift)
                ->slm_vertex_limit(shift);
}

sub pre_transform_vertices {
    return shift->_pp(aiProcess_PreTransformVertices)
                ->ptv_normalize(shift);
}

sub limit_bone_weights {
    return shift->_pp(aiProcess_LimitBoneWeights)
                ->lbw_max_weights(shift);
}

sub validate_data_structure {
    return shift->_pp(aiProcess_ValidateDataStructure);
}

sub improve_cache_locality {
    return shift->_pp(aiProcess_ImproveCacheLocality)
                ->icl_ptcache_size(shift);
}

sub remove_redundant_materials {
    return shift->_pp(aiProcess_RemoveRedundantMaterials)
                ->_rrm_exclude_list(shift);
}

sub fix_infacing_normals {
    return shift->_pp(aiProcess_FixInfacingNormals);
}

sub sort_by_ptype {
    my ($self, @types) = @_;
    return $self->_pp(aiProcess_SortByPType)
                ->sbp_remove_types(@types);
}

sub find_degenerates {
    return shift->_pp(aiProcess_FindDegenerates)
                ->fd_remove(shift);
}

sub find_invalid_data {
    return shift->_pp(aiProcess_FindInvalidData)
                ->fid_anim_accuracy(shift);
}

sub gen_uv_coords {
    return shift->_pp(aiProcess_GenUVCoords);
}

sub transform_uv_coords {
    return shift->_pp(aiProcess_TransformUVCoords);
}

sub find_instances {
    return shift->_pp(aiProcess_FindInstances);
}

sub optimize_meshes {
    return shift->_pp(aiProcess_OptimizeMeshes);
}

sub optimize_graph {
    return shift->_pp(aiProcess_OptimizeGraph);
}

sub flip_uvs {
    return shift->_pp(aiProcess_FlipUVs);
}

sub flip_winding_order {
    return shift->_pp(aiProcess_FlipWindingOrder);
}

sub split_by_bone_count {
    return shift->_pp(aiProcess_SplitByBoneCount)
                ->sbbc_max_bones(shift);
}

sub debone {
    return shift->_pp(aiProcess_Debone)
                ->db_all_or_none(shift)
                ->db_threshold(shift);
}


sub load {
    my ($self, $path) = @_;
    return Model3D::Assimp::Scene->new($path, @{$self}{qw/_ppflags _props/});
}


1;
