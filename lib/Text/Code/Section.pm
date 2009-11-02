package Text::Code::Section;
use strict; use warnings;
our $VERSION = '0.01';
use Moose;
use MooseX::Types::Moose qw( Str Int ArrayRef );
use Carp qw( croak );
use Text::Balanced qw( extract_quotelike );
use namespace::clean -except => 'meta';
use overload '""' => 'render', fallback => 1;

has 'parent'    => (
    is => 'ro', isa => 'Text::Code', required => 1,
    handles => [qw( uri basename language )],
);

has 'selector'      => ( is => 'ro', isa => 'Str' );

has 'tokens' => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);

has 'start_token'   => ( is => 'ro', lazy_build => 1 );
sub _build_start_token { ( shift->_get_start_end_tokens )[0] }

has 'end_token'     => ( is => 'ro', lazy_build => 1 );
sub _build_end_token { ( shift->_get_start_end_tokens )[1] }

has 'start_line'    => ( is => 'ro', isa => Int, lazy_build => 1 );
sub _build_start_line {
    my $self = shift;
    return $self->start_index - $self->parent->starting_line_number;
}
has 'end_line'      => ( is => 'ro', isa => Int, lazy_build => 1 );
sub _build_end_line {
    my $self = shift;
    return $self->end_index - $self->parent->starting_line_number;
}

has 'start_index' => (
    is => 'rw', isa => Int, lazy_build => 1,
    trigger => sub {
        my ( $self, $val ) = @_;
        if ( $val < 1 ) { croak "start_index less than 1" }
    },
);
sub _build_start_index {
    my $self = shift;
    my $token = $self->start_token || '+0';
    my $tc = $self->parent;
    return $self->find_index( $token, $tc, $tc->position )
        or croak "Unable to find start index for token '$token'";
}

has 'end_index'   => (
    is => 'rw', isa => Int, lazy_build => 1,
    trigger => sub {
        my ( $self, $val ) = @_;
        if ( $val > $self->parent->num_lines ) {
            croak "end_index greater than num_lines";
        }
    },
);
sub _build_end_index {
    my $self = shift;
    my $token = $self->end_token || '+0';
    return $self->find_index( $token, $self->parent, $self->start_index )
        or croak "Unable to find end index for token '$token'";
}

sub find_index {
    my ( $self, $token, $tc, $pos ) = @_;

    if ( my $ref = ref $token ) {
        if ( $ref eq 'Regexp' ) {
            return $tc->next_index_for_re( $token, $pos )
                or croak "No match found for $token";
        } else {
            croak "Invalid reference for token: '$ref'";
        }
    } elsif ( $token =~ /^\@?(\d+)$/ ) {
        return $1;
    } elsif ( $token =~ /^\@\-(\d+)$/ ) {
        return $tc->num_lines + 1 - $1;
    } elsif ( $token =~ /^\+(\d+)$/ ) {
        return $pos + $1;
    } elsif ( $token =~ /^\-(\d+)$/ ) {
        return $pos - $1;
    } elsif ( $token =~ /^\#(\d+)$/ ) {
        return $1 - $tc->starting_line_number;
    #} elsif ( $token =~ /^#\s*(.*)\s*$/ ) {
        # TODO allow '# foo' to search for the first comment that contains
        #      'foo', without having to worry about what the comment rules
        #      are for the current language
    } else {
        return $tc->next_index_for_string( $token, $pos )
            or croak "No match found for '$token'";
    }
}

has 'id'    => ( is => 'rw', isa => Str, lazy_build => 1 );
sub _build_id {
    my $self = shift;
    return join(
        '-', $self->parent->id, 's', $self->start_line, $self->end_line
    );
}

has 'raw_content'   => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_raw_content {
    my $self = shift;
    my $raw = $self->parent->raw_content;
    return [ @{ $raw }[ ( $self->start_index - 1 ) .. ( $self->end_index - 1 ) ] ];
}

has 'html_content'  => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_html_content {
    my $self = shift;

    my $html = $self->parent->html_content;
    return [ @{ $html }[ ( $self->start_index - 1 ) .. ( $self->end_index - 1 ) ] ];
}

has 'num_lines' => ( is => 'ro', isa => Int, lazy_build => 1 );
sub _build_num_lines {
    my $self = shift;
    return $self->end_index - $self->start_index;
}

sub render {
    my $self = shift;

    return join( '',
        $self->wrap_html(
            $self->render_raw,
            $self->render_html,
            $self->render_toolbar,
        )
    );
}

sub render_raw {
    my $self = shift;

    return (
        qq{<pre class="text-code-raw text-code-view" style="display: none">},
        join( "\n", $self->raw_content ),
        qq{</pre>},
    );
}

sub render_html {
    my $self = shift;

    return (
        qq{<pre class="text-code-html text-code-view">},
        join( "\n", $self->html_content ),
        qq{</pre>},
    );
}

sub render_toolbar {
    my $self = shift;

    my $start = $self->start_line;
    my $end = $self->end_line;
    my $file = $self->basename;
    my $uri = $self->uri;

    return qq{
        <div class="text-code-tools">
        <span class="text-code-file">
        <a href="$uri">$file</a> ( $start - $end )
        </span>
        <span class="text-code-buttons">
        <a class="text-code-show-raw button">raw</a>
        <a class="text-code-show-html button">html</a>
        </span>
        </div>
    };
}

sub wrap_html {
    my $self = shift;

    my $id = $self->id;
    return ( qq{<div id="$id" class="text-code">}, @_, qq{</div>} );
}

sub _get_start_end_tokens {
    my $self = shift;
    my @tokens = $self->tokens;
    if ( @tokens == 3 && $tokens[1] eq '..' ) { return @tokens[0,2] }
    if ( @tokens == 1 && $tokens[0] eq '..' ) { return ( 1, -1 ) }
    croak "Unable to identify start and end tokens";
}

sub _build_tokens {
    my $self = shift;

    my $text = $self->selector;

    my @tokens = ();
    while ( length( $text ) > 0 ) {
        $text =~ s/^\s*//;
        if ( my $res = extract_quotelike( $text ) ) {
            my $code = eval $res; ## no critic
            push( @tokens, $code )
        } elsif ( $text =~ s/^([#@+-]?\d+)// ) {
            push( @tokens, $1 );
        } elsif ( $text =~ s/^(-(?!\d)|\.\.)// ) {
            push( @tokens, '..' );
        } else {
            croak "Invalid selector: '$text'";
        }
    }
    return \@tokens;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Text::Code::Section = A chunk of code for the Text::Code highlight manager

=head1 SYNOPSIS

    use Text::Code;
    
    my $code = Text::Code->new( '/path/to/script.pl' );
    my $section = $code->section( 1, 10 );
    print $section->render_html;

=head1 DESCRIPTION

See L<Text::Code|Text::Code> for details.

=head1 METHODS

=head2 parent

=head2 uri

=head2 basename

=head2 language

=head2 start_token

=head2 end_token

=head2 start_index

=head2 end_index

=head2 start_line

=head2 end_line

=head2 id

=head2 has_id

=head2 clear_id

=head2 raw_content

=head2 has_raw_content

=head2 clear_raw_content

=head2 html_content

=head2 has_html_content

=head2 clear_html_content

=head2 num_lines

=head2 has_num_lines

=head2 clear_num_lines

=head2 render

=head2 render_raw

=head2 render_html

=head2 render_toolbar

=head2 wrap_html

=head1 MODULE HOME PAGE

The home page of this module is
L<http://www.jasonkohles.com/software/text-code>.  This is where you can
always find the latest version, development versions, and bug reports.  You
will also find a link there to report bugs.

=head1 SEE ALSO

L<http://www.jasonkohles.com/software/text-code>

L<Text::CodeBlog>

=head1 AUTHOR

Jason Kohles C<< <email@jasonkohles.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008,2009 Jason Kohles

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

