package Model3D::Assimp::Bone;

# ABSTRACT: Assimp bone
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY       bone_destroy
        name          bone_name
        offset_matrix bone_offset_matrix
        weights       bone_weights
    );
}

1;
