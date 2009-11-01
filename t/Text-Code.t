#!env perl
use strict; use warnings;
use Test::Most tests => 16;
use ok 'Text::Code';
use Path::Class qw( file );

my @text = split( "\n", +file( "t/test-code.pl" )->slurp, -1 );

ok( my $code = Text::Code->new( 't/test-code.pl' ), 'Loaded test-code.pl' );
isa_ok( $code, 'Text::Code' );
my @lazy_build_attrs = qw(
    id uri raw raw_content html_content
    language num_lines position
);
can_ok( $code,
    qw(
        file basename BUILDARGS next_index_for_re
        find_index section sections compute_coverage _print_covered
        show_coverage html_coverage default_language
    ),
    ( map { ( '_build_'.$_, 'clear_'.$_, 'has_'.$_ ) } @lazy_build_attrs ),
);
isa_ok( $code, 'Moose::Object' );

like( $code->id, qr/^\d+_\d+$/, 'randomly generated id looks ok' );
is( $code->language, 'Perl', 'Correctly detected perl' );

# Moose::Object methods
can_ok( $code, qw( new does dump ) );

is( scalar @{ $code->raw_content }, scalar @text, 'content size matchs' );
eq_or_diff( [ $code->raw_content ], \@text, 'code content matches' );
is( $code->language, 'Perl', 'Language is Perl' );
cmp_ok( $code->num_lines, '==', scalar @text, "Got correct number of lines" );

ok( my $s1 = $code->section( 1, 4 ), 'Extracted first 4 lines' );
isa_ok( $s1, 'Text::Code::Section' );
is_deeply( [ $s1->raw_content ], [ @text[ 0 .. 3 ] ], "text matches" );

is( scalar @{ $code->html_content }, scalar @text, 'content size matchs' );
