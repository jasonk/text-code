package Text::Code::Section;
use strict; use warnings;
our $VERSION = '0.01';
use Moose;
use MooseX::Types::Moose qw( Str Int ArrayRef );
use namespace::clean -except => 'meta';
use overload '""' => 'render', fallback => 1;

has 'parent'    => (
    is => 'ro', isa => 'Text::Code', required => 1,
    handles => [qw( file uri basename language )],
);

has 'start' => (
    is => 'rw', isa => Int, required => 1,
    trigger => sub {
        my ( $self, $val ) = @_;
        if ( $val < 1 ) { confess "start less than 1" }
    },
);

has 'end'   => (
    is => 'rw', isa => Int, required => 1,
    trigger => sub {
        my ( $self, $val ) = @_;
        if ( $val > $self->parent->num_lines ) {
            confess "end greater than num_lines";
        }
    },
);

has 'id'    => ( is => 'rw', isa => Str, lazy_build => 1 );

has 'raw_content'   => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_raw_content {
    my $self = shift;
    my $raw = $self->parent->raw_content;
    return [ @{ $raw }[ ( $self->start - 1 ) .. ( $self->end - 1 ) ] ];
}

has 'html_content'  => (
    is => 'ro', isa => ArrayRef, lazy_build => 1, auto_deref => 1
);
sub _build_html_content {
    my $self = shift;

    my $html = $self->parent->html_content;
    return [ @{ $html }[ ( $self->start - 1 ) .. ( $self->end - 1 ) ] ];
}

has 'num_lines' => ( is => 'ro', isa => Int, lazy_build => 1 );
sub _build_num_lines {
    my $self = shift;
    return $self->end - $self->start;
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

    my $start = $self->start;
    my $end = $self->end;
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

=head2 file

=head2 uri

=head2 basename

=head2 language

=head2 start

=head2 end

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

