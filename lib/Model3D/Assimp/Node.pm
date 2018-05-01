package Model3D::Assimp::Node;

# ABSTRACT: Assimp node
use strict;
use warnings;
use Model3D::Assimp::XS;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY        node_destroy
        name           node_name
        parent         node_parent
        children       node_children
        meshes         node_meshes
        transformation node_transformation
    );
}

1;
