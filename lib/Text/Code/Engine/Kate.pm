package Text::Code::Engine::Kate;
use strict; use warnings;
our $VERSION = '0.01';
our $AUTHORITY = 'cpan:JASONK';
use Moose;
extends 'Text::Code::Engine';
use Text::Code;
use MooseX::Types::Moose qw( Str );
use namespace::clean -except => 'meta';

BEGIN {
    my $err = do {
        local $@;
        eval { require Syntax::Highlight::Engine::Kate };
        $@;
    };

    my $reg = Text::Code::REGISTRY();
    my $pkg = __PACKAGE__;

    if ( $err ) {
        $reg->register_missing_engine( $pkg => $err );
    } else {
        my $kate = Syntax::Highlight::Engine::Kate->new;

        my $extensions = $kate->extensions;
        for my $ext ( keys %{ $extensions } ) {
            my @langs = @{ $extensions->{ $ext } };
            if ( $ext =~ s/^(\s*\*\.)// ) {
                my $save = $1;
                if ( Text::Code::Registry::_isglob( $ext ) ) {
                    $reg->register_globs( $save.$ext => @langs );
                } else {
                    $reg->register_extensions( $ext => @langs );
                }
            } elsif ( Text::Code::Registry::_isglob( $ext ) ) {
                $reg->register_globs( $ext => @langs );
            } else {
                $reg->register_names( $ext => @langs );
            }
        }
        my $syntaxes = $kate->syntaxes;
        for my $name ( keys %{ $syntaxes } ) {
            $reg->register_engine( $name => $pkg => $syntaxes->{ $name } );
        }
    }
}

our @FORMATS = qw(
    Alert BaseN BString Char Comment DataType DecVal Error Float Function
    IString Keyword Normal Operator Others RegionMarker Reserved String
    Variable Warning
);

has 'kate'  => (
    is => 'ro', isa => 'Syntax::Highlight::Engine::Kate', lazy => 1,
    default => sub {
        my $self = shift;
        my $fmap = $self->format_map;
        my %table = ();
        for my $format ( @FORMATS ) {
            my $mapped = $fmap->{ $format } || $format;
            $table{ $format } = [ qq{<span class="$mapped">}, qq{</span>} ];
        }
        return Syntax::Highlight::Engine::Kate->new(
            language        => $self->language,
            substitutions   => $self->substitution_map,
            format_table    => \%table,
        );
    },
);

has 'language'   => ( is => 'ro', isa => Str );

sub BUILDARGS {
    my $class = shift;
    if ( @_ == 1 && ! ref $_[0] ) { unshift( @_, 'language' ) }
    return $class->SUPER::BUILDARGS( @_ );
}

sub highlight {
    my ( $self, $tc ) = @_;
    return split( "\n", $self->kate->highlightText( $tc->raw ), -1 );
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Text::Code::Engine::Kate - Syntax::Highlight::Engine::Kate renderer for Text::Code

=head1 DESCRIPTION

See L<Text::Code|Text::Code> for details on how to use this.

=head1 MODULE HOME PAGE

The home page of this module is
L<http://www.jasonkohles.com/software/text-code>.  This is where you can
always find the latest version, development versions, and bug reports.  You
will also find a link there to report bugs.

=head1 SEE ALSO

L<Text::Code::Engine::Kate|Text::Code::Engine::Kate>

L<http://www.jasonkohles.com/software/text-code>

=head1 AUTHOR

Jason Kohles C<< <email@jasonkohles.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008,2009 Jason Kohles

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

