use inc::Module::Install;

name 'Text-Code';
all_from 'lib/Text/Code.pm';

requires( $_ ) for qw(
    Moose
    MooseX::Types
    MooseX::Types::Path::Class
    MooseX::Types::URI
    namespace::clean
    Syntax::Highlight::Engine::Kate
);

test_requires( $_ ) for qw(
    Test::Most
);

WriteAll();
