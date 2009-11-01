package Text::Code::Types;
use strict; use warnings;
our $VERSION = '0.01';
our $AUTHORITY = 'cpan:JASONK';
use MooseX::Types -declare => [qw(
    OptionalFile OptionalDir
)];
use MooseX::Types::Moose qw( Maybe Undef Str ArrayRef );
use MooseX::Types::Path::Class qw( File Dir );

subtype OptionalFile, as Maybe[File];
coerce OptionalFile,
    from Str, via { Path::Class::File->new( $_ ) },
    from ArrayRef, via { Path::Class::File->new( @{ $_ } ) };

subtype OptionalDir, as Maybe[Dir];
coerce OptionalDir,
    from Str, via { Path::Class::Dir->new( $_ ) },
    from ArrayRef, via { Path::Class::Dir->new( @{ $_ } ) };

1;
__END__

=head1 NAME

Text::Code::Types - MooseX::Types library for Text::Code

=head1 DESCRIPTION

This is a L<MooseX::Types|MooseX::Types> type library L<Text::Code|Text::Code>.

=head1 MODULE HOME PAGE

The home page of this module
is L<http://www.jasonkohles.com/software/text-code>.  This is where you can
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

