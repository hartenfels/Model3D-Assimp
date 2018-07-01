package Model3D::Assimp::MeshMorphAnim;

# ABSTRACT: Assimp mesh animation
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY mesh_morph_anim_destroy
        name    mesh_morph_anim_name
        keys    mesh_morph_anim_keys
    );
}

1;
