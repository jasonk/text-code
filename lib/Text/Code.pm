package Text::Code;
use strict; use warnings;
our $VERSION = '0.01';
use Moose;
use Text::Code::Types qw( OptionalFile );
use MooseX::Types::Moose qw( Str Int ArrayRef HashRef Maybe );
use MooseX::Types::URI qw( Uri );
use Text::Code::Section;
use Text::Code::Registry;
use feature 'state';
use Carp qw( croak );
use Module::Find qw();
use namespace::clean -except => 'meta';

{
    my $REGISTRY = Text::Code::Registry->new;
    sub REGISTRY { $REGISTRY }
}

has 'id'        => ( is => 'rw', isa => Str, lazy_build => 1 );
sub _build_id { return time.'_'.int(rand 1000 ) }

has 'uri'       => ( is => 'rw', isa => Uri, coerce => 1, lazy_build => 1 );
sub _build_uri { return URI->new( shift->file->basename, 'http' ) }

has 'filename'  => ( is => 'rw', isa => Maybe[Str], lazy_build => 1 );
sub _build_filename {
    my $self = shift;
    if ( $self->has_file ) { return $self->file->stringify }
    return;
}

has 'basename' => ( is => 'rw', isa => Maybe[Str], lazy_build => 1 );
sub _build_basename {
    my $self = shift;
    if ( $self->has_file ) { return $self->file->basename }
    if ( $self->has_filename ) {
        return Path::Class::File->new( $self->filename )->basename;
    }
    return;
}

has 'dirname' => ( is => 'rw', isa => Maybe[Str], lazy_build => 1 );
sub _build_dirname {
    my $self = shift;
    if ( $self->has_file ) { return $self->file->dirname }
    return;
}

has 'extension' => ( is => 'rw', isa => Maybe[Str], lazy_build => 1 );
sub _build_extension {
    my $self = shift;
    if ( $self->filename =~ /.+\.(\w{1,10})$/ ) { return lc( $1 ) }
    return;
}

has 'file'      => (
    is => 'rw', isa => OptionalFile, coerce => 1, lazy_build => 1,
);
sub _build_file {
    my $self = shift;
    if ( $self->has_filename ) {
        if ( -f $self->filename ) {
            return to_File( $self->filename );
        }
    }
    return;
}

has 'raw' => ( is => 'rw', isa => Str, lazy_build => 1 );
sub _build_raw { return scalar shift->file->slurp }

has "raw_content"   => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_raw_content { return [ split( "\n", shift->raw, -1 ) ] }

has 'starting_line_number' => ( is => 'rw', isa => Int, default => 1 );

has 'registry' => (
    is => 'rw', isa => 'Text::Code::Registry', default => sub { REGISTRY() },
);

has 'html_content'   => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_html_content {
    my $self = shift;

    my @content = $self->registry->highlight( $self );
    if ( my $line = $self->starting_line_number ) {
        my $wide = length( $line + $self->num_lines );
        my $lnl = qq{<span class="LineNo">};
        my $lnr = qq{</span>};
        for ( @content ) {
            my $x = ( '&nbsp;' x ( $wide - length( $line ) ) ).$line;
            s/^/${lnl}${x}${lnr}/;
            $line++;
        }
    }
    return \@content;
}

has 'language'  => ( is => 'rw', isa => Str, lazy_build => 1 );
sub _build_language { $_[0]->registry->detect_language( $_[0] ) }

has 'interpreter'   => ( is => 'ro', isa => Maybe[Str], lazy_build => 1 );
sub _build_interpreter {
    my $self = shift;

    my @raw = $self->raw_content;
    use Data::Dump qw( ddx );
    local $_ = $raw[0] or return;
    s/^#!// or return;  # drop the hashbang, if it doesn't have one,
                        # then we can't detect the interpreter

    my $interp;
    if ( s/^(\S+)\s*// ) {
        $interp = $1;
        if ( $interp =~ /\benv$/ ) {
            if ( s/^(\S+)\s*// ) { $interp = $1 }
        }
    }
    return $interp;
}

has 'interpreter_name'  => ( is => 'ro', isa => Maybe[Str], lazy_build => 1 );
sub _build_interpreter_name {
    my $self = shift;
    my $interp = $self->interpreter or return;
    return Path::Class::File->new( $interp )->basename;
}

has 'default_language' => ( is => 'rw', isa => Str, default => '' );

has 'num_lines' => ( is => 'ro', isa => Int, lazy_build => 1 );
sub _build_num_lines {
    my $self = shift;
    return scalar @{ $self->raw_content };
}

has 'position'  => (
    is => 'rw', isa => Int, lazy_build => 1,
    trigger => sub {
        my ( $self, $val ) = @_;
        if ( $val > $self->num_lines ) {
            $self->position( $self->num_lines );
        }
    }
);
sub _build_position { 1 }

sub BUILDARGS {
    my $class = shift;
    if ( @_ == 1 ) {
        my $arg = shift;
        if ( ! ref $arg ) {
            return $class->SUPER::BUILDARGS( { file => $arg } );
        } elsif ( ref $arg eq 'HASH' ) {
            return $class->SUPER::BUILDARGS( $arg );
        } elsif ( blessed( $arg ) ) {
            if ( $arg->isa( 'Path::Class::File' ) ) {
                return $class->SUPER::BUILDARGS( { file => $arg } );
            }
        }
        croak "Text::Code->new expected path or Path::Class::File, got $arg";
    }
    return $class->SUPER::BUILDARGS( @_ );
}

sub next_index_for_re {
    my ( $self, $re, $start ) = @_;
    $start ||= 1;

    my @raw = $self->raw_content;
    for my $i ( ( $start - 1 ) .. $#raw ) {
        if ( $raw[ $i - 1 ] =~ $re ) { return $i }
    }
    return undef; ## no critic
}

sub find_index {
    my ( $self, $text, $start ) = @_;
    $start ||= 1;

    $text =~ s/^\s*|\s*$//g;

    my $re;
    if ( $text =~ m{^/(.*)/(\w*)$} ) {
        $re = eval "qr/$1/$2"; ## no critic
        return $self->next_index_for_re( $re, $start );
    } elsif ( $text =~ /^\-(\d+)$/ ) {
        return $self->num_lines + 1 - $1;
    } elsif ( $text =~ /^\+(\d+)$/ ) {
        return $start + $1;
    } else {
        croak "Unable to find index from $text";
    }
}

sub section {
    my $self = shift;

    my ( $start, $end );

    if ( @_ == 1 && $_[0] =~ /^(.*)\s*\.\.\s*(.*)$/ ) {
        ( $start, $end ) = ( $1, $2 );
    } else {
        $start = shift || 1;
        $end = shift || $self->num_lines;
    }

    if ( $start =~ /^\s*$/ ) {
        $start = 1;
    } elsif ( $start =~ /^\d+$/ ) {
        # no-op, already specifies a line number
    } else {
        $start = $self->find_index( $start, $self->position );
    }

    if ( $end =~ /^\s*$/ ) {
        $end = $self->num_lines;
    } elsif ( $end =~ /^\d+$/ ) {
        # no-op
    } else {
        $end = $self->find_index( $end, $start + 1 );
    }

    state $subid = 1;
    my $section = Text::Code::Section->new( {
        parent      => $self,
        start       => $start,
        end         => $end,
        id          => $self->id . '-' . $subid++,
    } );
    push( @{ $self->sections }, $section );
    $self->position( $end + 1 );
    return $section;
}

has 'sections'     => ( is => 'ro', isa => ArrayRef, default => sub { [] } );

sub compute_coverage {
    my $self = shift;
    my @covered = map { 0 } 0 .. ( $self->num_lines - 1 );
    for my $section ( @{ $self->sections } ) {
        $covered[ $_-1 ]++ for $section->start .. $section->end;
    }
    return @covered;
}

BEGIN {
    my $have_ansicolor = do {
        local $@; 
        eval { require Term::ANSIColor };
        ! $@;
    };
    *_print_covered = $have_ansicolor
        ? sub {
            my $color = $_[1] ? 'green' : 'red';
            print Term::ANSIColor::colored( $_[0], $color )."\n";
        }
        : sub {
            printf( "% 3s %s\n", $_[1] || ' ', $_[0] );
        };
};

sub show_coverage {
    my $self = shift;
    my @coverage = $self->compute_coverage;
    my @raw = $self->raw_content;
    $self->_print_covered( $raw[ $_ ], $coverage[ $_ ] ) for 0 .. $#raw;
}

sub html_coverage {
    my $self = shift;
    my @coverage = $self->compute_coverage;
    my @raw = $self->raw_content;
    my @out = ();
    for my $i ( 0 .. $#raw ) {
        my @class = (
            ( $coverage[ $i ] ? 'text-code-covered' : 'text-code-uncovered' ),
            'text-code-cover-'.$coverage[ $i ]
        );
        push( @out, qq{<span class="@class"><pre>$raw[$i]</pre></span><br/>} );
    }
    return wantarray ? @out : join( "\n", @out );
}

sub import {
    my $class = shift;
    Module::Find::useall( 'Text::Code::Engine' );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Text::Code - Code highlighting manager

=head1 SYNOPSIS

    use Text::Code;
    
    my $code = Text::Code->new( '/path/to/script.pl' );
    my $s1 = $code->section( 1, 10 );
    print $s1->render_html;

=head1 DESCRIPTION

This module provides a management framework for source code highlighting.
It was originally part of the L<Text::CodeBlog|Text::CodeBlog> module, but
was split out as it became apparent that it could be very useful on it's own.

=head1 CLASS METHODS

=head2 Text::Code->REGISTRY()

Returns the global L<Text::Code::Registry|Text::Code::Registry> object.

=head2 my $code = Text::Code->new( '/path/to/file' );

Creates and returns a new L<Text::Code|Text::Code> object.  The new method is
inherited from L<Moose::Object|Moose::Object>.  If a single argument is passed
that is either a string or a L<Path::Class::File|Path::Class::File> object,
then it will be used as the L<file|/file> argument, otherwise the argument or
arguments to new are expected to conform to the requirements of
L<Moose::Object->new|Moose::Object/new>.

=head1 INSTANCE METHODS

=head2 id

Set or return this object's id.  The id is used primarily when producing
HTML output, it will be used as the C<id=""> attribute to the enclosing
HTML tag for the output.  If an id is not defined, a randomly generated one
will be provided.

=head2 has_id

Returns true if the object has an id defined.

=head2 clear_id

Clears the id of this object, which will result in a new randomly generated
id being assigned.

=head2 file

Set or retrieve the file path for this code object.  This is the path on the
filesystem where the code can be found.  Must be either a
L<Class::Path::File|Class::Path::File> object, or something that
L<MooseX::Types::Path::Class|MooseX::Types::Path::Class> can coerce to a
L<Class::Path::File|Class::Path::File>.

=head2 uri

Set or retrieve the URI for this code object.  This is the URL at which the
code can be found.  If you don't provide a URI, then the output will not
contain download links.  Must be either a L<URI|URI> object, or something that
L<MooseX::Types::URI|MooseX::Types::URI> can coerce to a L<URI|URI> object.

=head2 has_uri

Returns true if this object has a URI value set.

=head2 clear_uri

Clear the URI value from the object.

=head2 basename

Returns just the filename portion of the file path.

=head2 dirname

Returns just the directory portion of the file path.

=head2 raw_content

=head2 has_raw_content

=head2 clear_raw_content

=head2 html_content

=head2 has_html_content

=head2 clear_html_content

=head2 language

=head2 has_language

=head2 clear_language

=head2 num_lines

=head2 has_num_lines

=head2 clear_num_lines

=head2 position

=head2 has_position

=head2 clear_position

=head2 next_index_for_re

=head2 find_index

=head2 section

=head2 sections

=head2 compute_coverage

=head2 show_coverage

=head2 html_coverage

=head2 default_language

This method provides a default language, when all other methods of identifying
the language for a file have failed.  If this is set for an object, then the
language classifier will prefer this value as a default rather than using the
default_language value from
L<Text::Code::Registry|Text::Code::Registry/default_language>.

=head1 INTERNAL METHODS

These are methods you probably don't need to worry about unless you are
subclassing the module.

=head2 BUILDARGS

See L<BUILDARGS in Moose::Object|Moose::Object/BUILDARGS>.

=head2 _print_covered

=head1 MODULE HOME PAGE

The home page of this module is
L<http://www.jasonkohles.com/software/text-code>.  This is where you can
always find the latest version, development versions, and bug reports.  You
will also find a link there to report bugs.

=head1 SEE ALSO

L<Text::Code::Section|Text::Code::Section>

L<Text::CodeBlog|Text::CodeBlog>

L<http://www.jasonkohles.com/software/text-code>

=head1 AUTHOR

Jason Kohles C<< <email@jasonkohles.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008,2009 Jason Kohles

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

