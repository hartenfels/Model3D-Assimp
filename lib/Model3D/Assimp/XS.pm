package Model3D::Assimp::XS;

# ABSTRACT: Assimp XS
use strict;
use warnings;
use Carp qw(croak);
use List::Util qw(pairs);
use Exporter qw(import);

require XSLoader;
XSLoader::load('Model3D::Assimp', $Model3D::Assimp::XS::VERSION);

our %EXPORT_TAGS = (
    constants => [grep { /^(?:AI_|ai[A-Z])/ } keys %Model3D::Assimp::XS::],
);
Exporter::export_ok_tags('constants');

# Some objects can just call the XS functions directly, since they
# don't need to do any wrapping around them. This function takes
# care of renaming them and stuffing them into their package. This
# could probably be done with some CPAN Exporter module, but eh.
sub _alias {
    my ($package, @kvlist) = @_;
    for my $pair (pairs @kvlist) {
        my $from = $package    . '::' . $pair->[0];
        my $to   = __PACKAGE__ . '::' . $pair->[1];
        {
            no strict qw(refs);
            croak "_alias: '$to' is undefined" unless defined *{$to}{CODE};
            *{$from} = \&$to;
        }
    }
}

1;
