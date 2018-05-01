package Model3D::Assimp::Mesh;

# ABSTRACT: Assimp mesh
use strict;
use warnings;
use Model3D::Assimp::XS;
use Model3D::Assimp::Bone;

BEGIN {
    Model3D::Assimp::XS::_alias __PACKAGE__, qw(
        DESTROY           mesh_destroy
        name              mesh_name
        material_index    mesh_material_index
        primitive_types   mesh_primitive_types
        bitangents        mesh_bitangents
        bones             mesh_bones
        faces             mesh_faces
        normals           mesh_normals
        tangents          mesh_tangents
        vertices          mesh_vertices
    );
}


# Assimp stores a certain number of color sets and texture coordinates
# in each mesh. You can get at them either by index or by leaving out
# the index and getting them all. These subs dispatch to the correct XS
# function depending on if you gave an index or not, since doing that
# in C is pretty clunky. They could probably just call the _all method
# and give you the correct index instead, but eh, I already wrote the
# indexed methods, so I might as well keep using them. Slightly less
# brutally wasteful on your memory, too.

sub colors {
    return @_ > 1 ? Model3D::Assimp::XS::mesh_colors(@_)
                  : Model3D::Assimp::XS::mesh_all_colors(@_);
}

sub texture_coords {
    return @_ > 1 ? Model3D::Assimp::XS::mesh_texture_coords(@_)
                  : Model3D::Assimp::XS::mesh_all_texture_coords(@_);
}

sub num_uv_components {
    return @_ > 1 ? Model3D::Assimp::XS::mesh_num_uv_components(@_)
                  : Model3D::Assimp::XS::mesh_all_num_uv_components(@_);
}


1;
