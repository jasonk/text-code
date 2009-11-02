use inc::Module::Install;

name 'Text-Code';
author 'Jason Kohles <email@jasonkohles.com>';
license 'perl';
all_from 'lib/Text/Code.pm';
readme_from 'lib/Text/Code.pm';
requires( "namespace::clean" => 0 );
requires( "MooseX::Types::Path::Class" => 0 );
requires( "Syntax::Highlight::Engine::Kate" => 0 );
requires( "MooseX::Types" => 0 );
requires( "Moose" => 0 );
requires( "MooseX::Types::URI" => 0 );
test_requires( "Test::Most" => 0 );
auto_manifest;
extra_tests;
auto_license;
githubmeta;

WriteAll();
