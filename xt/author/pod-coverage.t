#!perl
use Test::More;
eval "use Test::Pod::Coverage 1.04";
if ( $@ ) { plan skip_all => "Test::Pod::Coverage 1.04 required" }
eval "use Pod::Coverage::Moose";
if ( $@ ) { plan skip_all => 'Pod::Coverage::Moose required' }
all_pod_coverage_ok( { coverage_class => 'Pod::Coverage::Moose' } );
#eval "use Pod::Coverage::Extended";
#use Pod::Coverage::Extended;
#if ( $@ ) { plan skip_all => 'Pod::Coverage::Extended required' }
#all_pod_coverage_ok( { coverage_class => 'Pod::Coverage::Extended' } );
