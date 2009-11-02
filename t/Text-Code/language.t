#!env perl
use strict; use warnings;
use Test::Most tests => 11;
use ok 'Text::Code';

my @samples = (
    {
        args                => [ 't/test-code.pl' ],
        interpreter         => '/usr/bin/perl',
        interpreter_name    => 'perl',
        language            => 'Perl',
        extension           => 'pl',
#        _find_language_from_interpreter => 'Perl',
#        _find_language_from_filename    => undef,
#        _find_language_from_extension   => 'Perl',
    },
    {
        args                => [
            filename            => 'foo.c',
            raw                 => '/* sample C code */',
        ],
        interpreter         => undef,
        interpreter_name    => undef,
        language            => 'C',
        extension           => 'c',
#        _find_language_from_interpreter => undef,
#        _find_language_from_filename    => undef,
#        _find_language_from_extension   => 'C',
    },
    {
        args                => [ {
            filename            => 'blah',
            raw                 => '#!/usr/bin/python',
        } ],
    },
);

for my $s ( @samples ) {
    my @args = @{ delete $s->{ 'args' } };
    ok( my $tc = Text::Code->new( @args ), 'new ok' );
    for my $key ( sort keys %{ $s } ) {
        is( $tc->$key, $s->{ $key }, "$key ok" );
    }
}
