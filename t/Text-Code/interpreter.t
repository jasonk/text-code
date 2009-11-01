#!env perl
use strict; use warnings;
use Test::Most tests => 29;
use ok 'Text::Code';

my @samples = (
    [ '#!/usr/bin/perl -w'      => '/usr/bin/perl'  ],
    [ '#!/usr/bin/perl'         => '/usr/bin/perl'  ],
    [ '#!perl'                  => 'perl'           ],
    [ '#!perl -w'               => 'perl'           ],
    [ '#!env perl'              => 'perl'           ],
    [ '#!env perl -w'           => 'perl'           ],
    [ '#!/usr/bin/env perl -wT' => 'perl'           ],
);

for my $s ( @samples ) {
    ok( my $tc = Text::Code->new( raw => "$s->[0]\n" ), "Built '$s->[0]'" );
    eq_or_diff( scalar $tc->raw_content, [ $s->[0], '' ], 'raw_content ok' );
    is( $tc->interpreter, $s->[1], 'interpreter is ok' );
    is( $tc->interpreter_name, 'perl', 'interpreter_name is ok' );
}
