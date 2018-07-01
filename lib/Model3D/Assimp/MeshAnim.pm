package Model3D::Assimp::MeshAnim;

# ABSTRACT: Assimp mesh animation
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY mesh_anim_destroy
        name    mesh_anim_name
        keys    mesh_anim_keys
    );
}

1;
