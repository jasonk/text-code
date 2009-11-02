package Text::Code::Registry;
use strict; use warnings;
our $VERSION = '0.01';
our $AUTHORITY = 'cpan:JASONK';
use Moose;
use MooseX::Types::Moose qw( HashRef ArrayRef Str );
use MooseX::Types::Set::Object;
use List::Util qw( first max );
use Carp qw( croak );
use Text::Glob qw( match_glob );
use namespace::clean -except => 'meta';

has 'default_language' => ( is => 'rw', isa => Str, default => '' );

# extension_map: { 'extension' => [ 'language1', 'language2' ] }
has 'extension_map' => ( is => 'rw', isa => HashRef, default => sub { {} } );
# name_map: { 'filename' => [ 'language1', 'language2' ] }
has 'name_map' => ( is => 'rw', isa => HashRef, default => sub { {} } );
# glob_map: { 'filename_glob.*' => [ 'language1', 'language2' ] }
has 'glob_map' => ( is => 'rw', isa => HashRef, default => sub { {} } );
# interpreter_map: { 'interpreter' => [ 'language1', 'language2' ] }
has 'interpreter_map' => ( is => 'rw', isa => HashRef, default => sub { {} } );

# engine_map: { 'language name' => [ 'Engine::Class' => @args ] }
has 'engine_map' => ( is => 'rw', isa => HashRef, default => sub { {} } );

sub register_extension {
    my ( $self, $extension, $lang ) = @_;
    $extension =~ s/^\*\.//;
    $self->_register( extension_map => lc( $extension ) => $lang );
}

sub prefer_extension {
    my ( $self, $extension, $lang ) = @_;
    $extension =~ s/^\*\.//;
    $self->_prefer( extension_map => lc( $extension ) => $lang );
}

our $globre = qr/[\*\?\[\]]/;
sub _isglob { return $_[0] =~ $globre }

sub register_name {
    my ( $self, $name, $lang ) = @_;
    return $self->register_glob( $name => $lang ) if _isglob( $name );
    $self->_register( name_map => $name => $lang );
}
sub prefer_name {
    my ( $self, $name, $lang ) = @_;
    return $self->register_glob( $name => $lang ) if _isglob( $name );
    $self->_prefer( name_map => $name => $lang );
}

sub register_glob {
    my ( $self, $glob, $lang ) = @_;
    return $self->register_name( $glob => $lang ) unless $glob =~ $globre;
    $self->_register( glob_map => $glob => $lang );
}
sub prefer_glob {
    my ( $self, $glob, $lang ) = @_;
    return $self->prefer_name( $glob => $lang ) unless $glob =~ $globre;
    $self->_prefer( glob_map => $glob => $lang );
}

sub register_interpreter {
    my ( $self, $interpreter, $lang ) = @_;
    $self->_register( interpreter_map => $interpreter => $lang );
}
sub prefer_interpreter {
    my ( $self, $interpreter, $lang ) = @_;
    $self->_prefer( interpreter_map => $interpreter => $lang );
}

sub register_engine {
    my ( $self, $lang, $engine, @args ) = @_;
    $self->engine_map->{ $lang } = [ $engine, @args ];
    $self->loaded_engines->{ $engine }++;
}

has 'missing_engines' => ( is => 'ro', isa => HashRef, default => sub { {} } );
sub register_missing_engine {
    my ( $self, $engine, $error ) = @_;
    $self->missing_engines->{ $engine } = $error;
}

has 'loaded_engines' => ( is => 'ro', isa => HashRef, default => sub { {} } );

has 'language_detection_order' => ( is => 'rw', isa => Str, lazy_build => 1 );
sub _build_language_detection_order { 'interpreter,extension,name,glob' }

sub detect_languages {
    my ( $self, $tc, $store ) = @_;

    my @order = split( /\s*,\s*/, $self->language_detection_order );

    my %langs = ();
    my %ranks = ();
    my $rank = 1;

    for my $order ( @order ) {
        my $method = '_detect_language_from_'.$order;
        next unless $self->can( $method );
        for my $lang ( $self->$method( $tc ) ) {
            $langs{ $lang }++;
            $ranks{ $lang } ||= $rank++;
        }
    }

    my %popular = ();
    for my $lang ( keys %langs ) {
        push( @{ $popular{ $langs{ $lang } } ||= [] }, $lang );
    }
    my %popularity = ();
    for my $key ( keys %popular ) {
        for my $lang ( @{ $popular{ $key } } ) {
            $popularity{ $lang } = $key;
        }
    }
    use Data::Dump qw( ddx );
    my @languages = sort {
        $popularity{ $b } <=> $popularity{ $a } ||
        $ranks{ $a } <=> $ranks{ $b }
    } keys %ranks;
    return @languages;
}

sub detect_language {
    my ( $self, $tc ) = @_;

    my @langs = $self->detect_languages( $tc );

    return $langs[0]
        || $tc->default_language
        || $self->default_language
        || croak "Unable to determine language of ".$tc->filename."\n";
}

sub _detect_language_from_interpreter {
    my ( $self, $tc ) = @_;

    my $int = $tc->interpreter_name or return;

    return @{ $self->interpreter_map->{ $int } || [] };
}

# TODO
#    for my $language ( $self->registry->languages ) {
#        if ( lc( $language ) eq $int ) { return $language }
#    }

sub _detect_language_from_extension {
    my ( $self, $tc ) = @_;

    my $ext = $tc->extension or return;
    return @{ $self->extension_map->{ $ext } || [] };
}

sub _detect_language_from_name {
    my ( $self, $tc ) = @_;

    my $basename = $tc->basename or return;
    return @{ $self->name_map->{ $basename } || [] };
}

sub _detect_language_from_glob {
    my ( $self, $tc ) = @_;
    my $globs = $self->glob_map;
    for my $glob ( keys %{ $globs } ) {
        if ( match_glob( $glob, $tc->filename ) ) {
            return @{ $globs->{ $glob } }; ## no critic
        }
    }
    return;
}

sub highlight {
    my ( $self, $tc ) = @_;

    my $lang = $tc->language;
    my $args = $self->engine_map->{ $lang }
        || croak "No engine found for language '$lang'";
    my $class = shift( @{ $args } );
    my $engine = $class->new( @{ $args } );

    return $engine->highlight( $tc );
}

sub _register {
    my ( $self, $what, $key, @langs ) = @_;
    my $x = $self->$what->{ $key } ||= [];
    for my $lang ( @langs ) {
        push( @{ $x }, $lang ) unless first { $_ eq $lang } @{ $x };
    }
}
sub _unregister {
    my ( $self, $what, $key, @langs ) = @_;
    my $x = $self->$what->{ $key } ||= [];
    my %remove = map { ( $_ => 1 ) } @langs;
    for my $i ( reverse 0 .. $#{ $x } ) {
        if ( $remove{ $x->[ $i ] } ) { splice( @{ $x }, $i, 1 ) }
    }
}
sub _prefer {
    my ( $self, $what, $key, @langs ) = @_;
    $self->_unregister( $what, $key, @langs );
    my $x = $self->$what->{ $key } ||= [];
    unshift( @{ $x }, @langs );
}

sub languages {
    my $self = shift;
    my %langs = ();
    for my $x (qw( extension_map name_map glob_map interpreter_map )) {
        $langs{ $_ } = 0 for map { @{ $_ } } values %{ $self->$x };
    }
    my $engines = $self->engine_map;
    for my $lang ( keys %{ $engines } ) {
        $langs{ $lang } = $engines->{ $lang }->[ 0 ];
    }
    return wantarray ? keys %langs : \%langs;
}

sub engineless_languages {
    my $self = shift;
    my $langs = $self->languages;
    return grep { $langs->{ $_ } } keys %{ $langs };
}

sub BUILD {
    my ( $self, $args ) = @_;

    $self->register_name( 'Changes' => 'Change Log' );
    $self->register_name( 'makefile' => 'Makefile' );
    $self->register_interpreter( 'perl' => 'Perl' );
    $self->register_interpreter( 'sh' => 'Bash' );
    $self->register_interpreter( 'bash' => 'Bash' );
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Text::Code::Registry - Highlight engine and language registry for Text::Code

=head1 DESCRIPTION

This is used internally by L<Text::Code|Text::Code>, you probably don't need
to use it directly.

=head1 METHODS

=head2 register_extension / prefer_extension

Registers an extension with the automatic language classifier.  See L</LANGUAGE
CLASSIFICATION> for more details.  Note that extensions are always converted
to lower case when being added to the map, and always compared in lower case,
so you cannot differentiate between upper-case extensions and lower-case
extensions.

=head2 register_name / prefer_name

Registers a file name with the automatic language classifier.
See L</LANGUAGE CLASSIFICATION> for more details.

=head2 register_glob / prefer_glob

Registers a filename glob with the automatic language classifier.
See L</LANGUAGE CLASSIFICATION> for more details.

=head2 register_interpreter / prefer_interpreter

Registers an interpreter name with the automatic language classifier.
See L</LANGUAGE CLASSIFICATION> for more details.

=head2 register_engine( 'Language', 'Engine::Class', @args );

Registers a L<Text::Code::Engine|Text::Code::Engine> subclass to handle
rendering for the given language.  The second argument is which subclass to
use, and any arguments that follow it are simply recorded, and later used when
calling C<< ->new >> on the L<Text::Code::Engine|Text::Code::Engine> subclass.

=head2 detect_language( $text_code_object )

Given a L<Text::Code|Text::Code> object, the detect_language method runs it
through the automatic language classifier and then selects the best match
of the possible languages.  See L</LANGUAGE CLASSIFICATION> for more details.

=head2 detect_languages( $text_code_object );

Given a L<Text::Code|Text::Code> object, the detect_languages method will
return a list of the possible languages for that object, sorted in preference
order (meaning the best match will be first in this list).

=head2 languages

Returns a (unordered) list of languages that the Registry knows about.

=head2 engineless_languages;

Returns a list of languages that the registry knows about, but for which there
is no registered plugin to highlight that language.

=head2 highlight

This is a helper method that takes a L<Text::Code|Text::Code> object, finds
the best matching engine to render it with, then passes it on to that engine,
and returns the rendered HTML output.

=head2 missing_engines

This method returns a hashref where the keys are the class names of engines
that couldn't be loaded (probably because they were missing prerequisite modlues) and the error message that was returned when attempting to load them.  This
was part of a plan to make L<Text::Code|Text::Code> warn you when no engines
could be loaded, though that isn't finished yet.

# TODO

=head2 register_missing_engine( $class, $error )

This is a helper method that allows you to add an engine to the missing engines
list.

=head1 LANGUAGE CLASSIFICATION

The prefer_extension method is just like L</register_extension>, except that
the language associated with the extension is moved to the front of the
search list for that extension, giving it priority.  Note that unlike
register_extension, which doesn't add it again if it is already on the list,
prefer_extension will move an existing entry to the front of the list.

=head1 MODULE HOME PAGE

The home page of this module
isL<http://www.jasonkohles.com/software/text-code>.  This is where you can
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

