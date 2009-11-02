#!env perl
use strict; use warnings;
use Test::Most tests => 65;
use ok 'Text::Code';
use ok 'Text::Code::Section';

my $code = Text::Code->new( 't/test-code.pl' );

my @selectors = (
    [ '1 .. 10', 1, '..', 10 ],
    [ '1..10', 1, '..', 10 ],
    [ '1 - 10', 1, '..', 10 ],
    [ 'qr/foo/..qr/bar/', qr/foo/, '..', qr/bar/ ],
    [ 'q/foo/ .. q/bar/', 'foo', '..', 'bar' ],
    [ 'qr/foo/i..qr/bar/ms', qr/foo/i, '..', qr/bar/ms ],
    [ '"foo" .. "bar"', 'foo', '..', 'bar' ],
);

for my $s ( @selectors ) {
    $code->clear_position;
    my @s = @{ $s };
    ok( my $in = shift( @s ), 'got $in' );
    ok( my $x = $code->section( $in ), 'build section' );
    isa_ok( $x, 'Text::Code::Section' );
    isa_ok( $x, 'Moose::Object' );
    is( $x->selector, $in, 'selector matches input' );
    ok( my @tokens = $x->tokens, 'got tokens' );
    eq_or_diff( \@tokens, \@s, $in );
    is( $x->start_token, $s[0], 'start_token ok' );
    is( $x->end_token, $s[2], 'end_token ok' );
}
