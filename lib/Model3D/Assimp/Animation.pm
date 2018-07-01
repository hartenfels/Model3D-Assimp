package Model3D::Assimp::Animation;

# ABSTRACT: Assimp animation
use strict;
use warnings;
use Model3D::Assimp::XS;
use Model3D::Assimp::MeshAnim;
use Model3D::Assimp::NodeAnim;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY          animation_destroy
        name             animation_name
        duration         animation_duration
        ticks_per_second animation_ticks_per_second
        channels         animation_channels
        mesh_channels    animation_mesh_channels
    );
}

1;
