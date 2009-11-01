#!env perl -w
use strict; use warnings;
use FindBin qw( $Bin );
use lib "$Bin/lib";

my $text = join( ' ', @ARGV ) || 'Hawaii is 4807 miles from Ashburn.';

$text =~ s{ \b ( (?:\d+)(?:\.\d+)? ) \s+ (kilometer|mile)s? }
          { convert( $1, $2 ) }xeg;

print "$text\n";

sub convert {
    my ( $q, $l ) = @_;

    my $x = sprintf( '%.2f', $1 * ( lc( $l ) eq 'mile' ? 1.609 : 0.6214 ) );
    return $x.' '.( $l eq 'mile' ? 'kilometer' : 'mile' ).( $x > 1 ? 's' : '' );
}
