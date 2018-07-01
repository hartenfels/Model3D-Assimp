package Model3D::Assimp::NodeAnim;

# ABSTRACT: Assimp node animation
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY       node_anim_destroy
        node_name     node_anim_node_name
        position_keys node_anim_position_keys
        rotation_keys node_anim_rotation_keys
        scaling_keys  node_anim_scaling_keys
    );
}


our %STATES = (
    Model3D::Assimp::XS::aiAnimBehaviour_DEFAULT,  'default',
    Model3D::Assimp::XS::aiAnimBehaviour_CONSTANT, 'constant',
    Model3D::Assimp::XS::aiAnimBehaviour_LINEAR,   'linear',
    Model3D::Assimp::XS::aiAnimBehaviour_REPEAT,   'repeat',
);

sub _to_state {
    my ($state) = @_;
    return $STATES{$state};
}

sub pre_state {
    return _to_state(Model3D::Assimp::XS::node_anim_pre_state(@_));
}

sub post_state {
    return _to_state(Model3D::Assimp::XS::node_anim_post_state(@_));
}


1;
