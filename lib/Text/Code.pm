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
    my $self = shift;
    my $regexp = shift;
    my $start = @_ ? shift : $self->position;
    $start ||= 1;

    my @raw = $self->raw_content;
    for my $i ( $start .. @raw ) {
        if ( $raw[ $i - 1 ] =~ $regexp ) { return $i }
    }
    return undef; ## no critic
}

sub next_index_for_string {
    my $self = shift;
    my $string = shift;
    my $start = @_ ? shift : $self->position;
    $start ||= 1;

    my @raw = $self->raw_content;
    for my $i ( $start .. @raw ) {
        if ( index( $raw[ $i - 1 ], $string ) >= 0 ) { return $i }
    }
}

sub section {
    my $self = shift;
    my $section;
    if ( @_ == 2 ) {
        $section = Text::Code::Section->new(
            parent      => $self,
            start_token => $_[0],
            end_token   => $_[1],
        );
    } elsif ( @_ == 1 ) {
        $section = Text::Code::Section->new(
            parent      => $self,
            selector    => $_[0],
        );
    } elsif ( @_ == 0 ) {
        $section = Text::Code::Section->new( parent => $self );
    }
    push( @{ $self->sections }, $section );
    $self->position( $section->end_index + 1 );
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

=head2 Text::Code->import

The import method provided by L<Text::Code|Text::Code> doesn't actually import
any functions, but it does call L<Module::Find->useall|Module::Find/useall> to
load all the installed L<Text::Code::Engine|Text::Code::Engine> subclasses.  If
you only want to load specific engines, rather than loading them all, or you
want to load them in a specific order, you can provide an empty set of
parentheses when calling C<use Text::Code>, to prevent this automatic loading
from occurring.

    use Text::Code (); # no automatically loaded engines
    use Text::Code::Engine::Kate; # only load the Kate engine

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

=head2 raw

The raw source code you will be highlighting.  You can pass this as an argument
to the constructor to build a L<Text::Code|Text::Code> object in memory for
code that doesn't actually exist on disk.

=head2 raw_content

Returns an array ref consisting of one element in the array for each line of
the original source code.

=head2 has_raw_content

Returns true if the raw_content array has been populated.

=head2 clear_raw_content

Clear the raw_content array.  You might need to do this if you change the
L<raw|/raw> value and want it to be recomputed.

=head2 html_content

Returns an array ref consisting of one element in the array for each line of
the original source code.  Unlike L<raw_content|/raw_content>, which simply
breaks up the value from L<raw|/raw> into lines, this holds the rendered HTML
output from the L<Text::Code::Engine|Text::Code::Engine> subclass that rendered
it.

=head2 has_html_content

Returns true if the html_content array has been populated.  If this is true, it
means the rendering is complete.

=head2 clear_html_content

Clear the html_content array.  Calling this removes the rendered output,
allowing it to be re-rendered if other values have changed.

=head2 language

Get or set the language that the current code is written in (or at least the
language that it should be syntax colored as).  If this is not set when it
comes time to render (or if you ask for the language, and one has not been set)
then the L<detect_language method of
Text::Code::Registry|Text::Code::Registry/detect_language> will be called to
attempt to determine the language.

=head2 has_language

Returns true if the language has been set.  This means either it was provided
manually by you, or it has already been auto-detected by the
L<registry|Text::Code::Registry/detect_language>.

=head2 clear_language

Clear the L<language|/language> setting, allowing it to be recalculated.

=head2 num_lines

Returns the number of lines of source code contained in this object.

=head2 has_num_lines

Returns true if the number of lines has been computed already.

=head2 clear_num_lines

Clear the number of lines value, which may be necessary if you change the
source code that needs rendering.

=head2 position

The current position of the 'location memory' flag.  This allows you to step
through code and ask for a section consisting of (for example) 'the next ten
lines'.

=head2 has_position

Returns true if the position value is currently set, indicating that at least
one section has been requested (or the position itself has been requested).

=head2 clear_position

Clear the position memory flag, resetting the position to the beginning of the
source code.

=head2 next_index_for_re( qr/some regexp/, $start )

Given a regexp, returns the line index of the next line that matches that
regexp, starting at line C<$start>.  If not specified, or false, then
C<$start> defaults to 1.

=head2 find_index( $text, $start )

The find_index method implements the range locators necessary for the
L<section|/section> method to return a chunk of the code.  The C<$text>
argument is a scalar representation of a 'section locator' which is subject
to the following rules:

=over 4

=item // - regexp

If given a string that starts with a slash, and ends with a slash and
optionally some following letters (i.e. a standard perl-style regexp, such as
/foo/ or /bar/xi), returns the next index that matches that regexp, starting
with the line indicated by C<$start>.

=item -123 - negative number

If given a number preceded by a dash, returns an index corresponding to that
number of lines from the end of the code (similar to what happens when you
provide a negative array subscript).  Note that in this case, the C<$start>
value is ignored, and I haven't decided yet whether that is a bug or not.

=item +321 - positive number

If given a number preceded by a plus-sign, returns the index that is that
number of lines from the start position.

=back

Note that you really shouldn't ever need to use L<find_index|/find_index>
yourself, it is primarily called by L<section|/section> when attempting to
locate a chunk of code.

# TODO - these should probably make sure the value they return is not outside
#        the range of 1-num_lines

=head2 section

The section method takes an argument (or arguments) indicating a range of lines
to extract.  It returns a L<Text::Code::Section|Text::Code::Section> object
that encapsulates those lines.

In order to extract a section, you have to specify the starting and ending
indexes of the section you want to extract.  If you provide two arguments, they
are assumed to be the start and end indicators.  If you provide only one
argument then it is checked to see whether it contains a 'range indicator'.  If it does, then the string is split on the range indicator and the two parts become the start and end indicators.

The string contains a range indicator if it matches either C<qr/\.\./> or C<qr/ - />.  Note that in the second case there MUST be white space on both sides of the dash.

If you provide only one argument, and it does not contain a range indicator,
then the argument provided will be interpreted as the starting point, and the
ending point will be set to '+0', resulting in you getting back a section
consisting of only one line.

Note that after the arguments are parsed, if the resulting ending index is
smaller than the starting index, then the values will be swapped.

=head3 STARTING INDEX

The first argument is the starting index (C<$start>).

If C<$start> is empty or contains only whitespace, then the section will
start with the L<current position|/position>.

If C<$start> contains an integer (with no prefix, or prefixed with an at-sign),
then that number will be used as the starting index.

If C<$start> contains an integer preceded by a hash sign (C<#>), then the line
number that corresponds to that integer will be used as the starting index.
(See L</LINE NUMBERING|LINE NUMBERING> for more information about line
numbers).

If C<$start> contains a number preceded by a plus or minus sign, then the
startining index will be set to that number of lines before or after the
L<current position|/position>.

If C<$start> starts with a forward slash, then it will be interpreted as a
regular expression, and the starting index will be the next line (after the
L<current position|/position> that matches the regexp.

Any other value will result in an exception.

=head3 ENDING INDEX

The second argument is the ending index (C<$end>).

If C<$end> is empty or contains only whitespace, then the section will end with
the last line of code.

If C<$end> contains an integer, then that number wll be used as the ending
index.

If C<$end> contains an integer preceded by a hash sign (C<#>), then the line
number that corresponds to that integer will be used as the ending index.
(See L</LINE NUMBERING|LINE NUMBERING> for more information about line
numbers).

If C<$end> contains a number preceded by a plus or minus sign, then the
ending index will be set to that number of lines before or after the
starting index.  Note that unlike the starting index, which is relative to
the current position, the ending index is relative to the starting index.  This allows you to do things like C<< my $section = $tc->section( '..+5' ) >>.

If C<$end> starts with a forward slash, then it will be interpreted as a
regular expression, and the ending index will be the next line (after the
starting index) that matches the regexp.

Any other value will result in an exception.

=head3 LINE NUMBERING

There needs to be a bit of a description as to how line numbering affects the
starting and ending index selectors when requesting a section.  You can
indicate an index using either an index number (C<< ->section( 105 ) >>), or a
line number (C<< ->section( '#105' ) >>).  The difference between these two
values has to do with the setting of the
L<starting_line_number|/starting_line_number> attribute.  If
starting_line_number is 1 (the default), then '105' and '#105' both refer to
the 105th line of the source code file (i.e. C<< $tc->raw_content->[104] >>).
If, however, starting_line_number is not 1, then the line numbers don't line up
with their indexes.  So if L<starting_line_number|/starting_line_number> is set to '100', then C<< ->section( '105' ) >> will now return the line that would be displayed as line number 205 when it is rendered, while C<< ->section( '#105' ) >> 

=head3 SECTION EXAMPLES

Here are some examples of arguments you can provide to the ->section method,
and how they will be interpreted.

=over 4

=item 1..10

The first 10 lines of the code.

    if ( $end =~ /^\s*$/ ) {
        $end = $self->num_lines;
    } elsif ( $end =~ /^\d+$/ ) {
        # no-op
    } else {
        $end = $self->find_index( $end, $start + 1 );
    }

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

