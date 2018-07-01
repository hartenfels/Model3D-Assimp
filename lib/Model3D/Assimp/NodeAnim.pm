package Model3D::Assimp::NodeAnim;

# ABSTRACT: Assimp node animation
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY       node_anim_destroy
        node_name     node_anim_node_name
        pre_state     node_anim_pre_state
        post_state    node_anim_post_state
        position_keys node_anim_position_keys
        rotation_keys node_anim_rotation_keys
        scaling_keys  node_anim_scaling_keys
    );
}

1;
