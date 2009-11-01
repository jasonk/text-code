package Text::Code::Engine;
use strict; use warnings;
our $VERSION = '0.01';
our $AUTHORITY = 'cpan:JASONK';
use Moose;
use namespace::clean -except => 'meta';

has 'format_map' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'substitution_map' => (
    is => 'rw', isa => 'HashRef', default => sub {
        return {
            '<'     => '&lt;',
            '>'     => '&gt;',
            '&'     => '&amp;',
            ' '     => '&nbsp;',
            "\t"    => '&nbsp;' x 4,
            #"\n"    => "<br />\n",
        };
    },
);

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Text::Code::Engine - Rendering engine base class for Text::Code

=head1 SYNOPSIS

    package Text::Code::Engine::MyEngine;
    use Moose;
    extends 'Text::Code::Engine';

    sub highlight {
        my ( $self, $tc ) = @_;
        # ... magic handwaving ...
        return @results_as_lines;
    }

=head1 DESCRIPTION

This is a base class for implementing highlighting engines.

=head1 METHODS

=head1 ABSTRACT METHODS

These are the methods you must override in order create a subclass of this
module.

=head2 $engine->highlight( $text_code_object );

The highlight method is called with one argument, the L<Text::Code|Text::Code>
object that needs highlighting.  It should process it into HTML as necessary
and return an array consisting of one element per line of output.  Note that
the 'element per line' is very important.  The HTML that is produced can
contain newlines in the array elements, but each line of the original source
code should result in one array element, since the line numbering code is going
to insert a line number at the beginning of each array element.

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

