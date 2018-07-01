use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use List::Util qw(pairs);
use Model3D::Assimp;
use Model3D::Assimp::XS qw(:constants);

my $dir = dirname(__FILE__);


my $scene = Model3D::Assimp->new->load("$dir/data/cube.dae");
ok $scene, 'loaded cube scene';

like $scene->flags, qr/\A[0-9]+\z/, 'scene flags look flaggy';


my $root = $scene->root_node;
ok $root, 'got root node';
isa_ok $root, 'Model3D::Assimp::Node';

is $root->name, 'Scene', 'root node name is Scene';
is $root->parent, undef, 'root node has no parent';

cmp_ok scalar $root->children, '==', 3, 'root node has 3 children';
is_deeply [map { $_->name } $root->children], [qw(Camera Lamp Cube)],
          'root node children are camera, lamp and cube';

is scalar $root->meshes, undef, 'root node has no defined mesh indices at all';
is_deeply [$root->meshes], [], "in list context it's an empty list";

is_deeply $root->transformation,
          [[1,  0, 0, 0],
           [0,  0, 1, 0],
           [0, -1, 0, 0],
           [0,  0, 0, 1]],
          'transformation is... that matrix, whatever it is';


sub sizes_ok {
    my ($obj, $method, $size, $title, @args) = @_;

    my $scalar = $obj->$method(@args);
    my @list   = $obj->$method(@args);
    my $call   = sprintf '%s->%s(%s)', $title, $method, join ', ', @args;

    if (defined $size) {
        ok defined $scalar, "scalar $call is defined";
        cmp_ok $scalar, '==', $size, "scalar $call gives $size";
    }
    else {
        is $scalar, undef, "scalar $call gives undef";
        $size = 0;
    }

    cmp_ok scalar @list, '==', $size, "($call) has size $size";
}


sizes_ok $scene, 'meshes', 1, 'scene';
my $mesh = ($scene->meshes)[0];
isa_ok $mesh, 'Model3D::Assimp::Mesh';

is $mesh->name, 'Cube', 'the mesh is the cube';
cmp_ok $mesh->material_index, '==', 0, 'cube uses the first material index';
like $mesh->primitive_types, qr/\A[0-9]+\z/, 'cube ptype flags look flaggy';


sizes_ok $mesh, 'faces', 12, 'cube';
is_deeply [$mesh->faces], [map { [$_ * 3, $_ * 3 + 1, $_ * 3 + 2] } 0 .. 11],
          'cube faces are like [[0, 1, 2], [3, 4, 5], ... [33, 34, 35]]';

sizes_ok $mesh, 'vertices', 36, 'cube';
sizes_ok $mesh, 'normals',  36, 'cube';

sizes_ok $mesh, 'bitangents',     undef, 'cube';
sizes_ok $mesh, 'tangents',       undef, 'cube';
sizes_ok $mesh, 'bones',          undef, 'cube';
sizes_ok $mesh, 'colors',         undef, 'cube', 0;
sizes_ok $mesh, 'texture_coords', undef, 'cube', 0;

cmp_ok $mesh->num_uv_components(0), '==', 0,
       'cube uv components count is zero';

sizes_ok $mesh, 'colors',            AI_MAX_NUMBER_OF_COLOR_SETS,    'cube';
sizes_ok $mesh, 'texture_coords',    AI_MAX_NUMBER_OF_TEXTURECOORDS, 'cube';
sizes_ok $mesh, 'num_uv_components', AI_MAX_NUMBER_OF_TEXTURECOORDS, 'cube';

is_deeply [$mesh->colors], [(undef) x AI_MAX_NUMBER_OF_COLOR_SETS],
          'cube colors are AI_MAX_NUMBER_OF_COLOR_SETS undefs';

is_deeply [$mesh->texture_coords], [(undef) x AI_MAX_NUMBER_OF_TEXTURECOORDS],
          'cube texture_coords are AI_MAX_NUMBER_OF_TEXTURECOORDS undefs';

is_deeply [$mesh->num_uv_components], [(0) x AI_MAX_NUMBER_OF_TEXTURECOORDS],
          'cube num_uv_components are AI_MAX_NUMBER_OF_TEXTURECOORDS zeros';


sizes_ok $scene, 'animations', undef, 'cube';


done_testing;
