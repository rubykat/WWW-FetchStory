package WWW::FetchStory::Fetcher::Owl;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::Owl - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the Owl story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic Owl fetcher, and then refinements for particular
Owl community, such as the sshg_exchange community.
This works as either a class function or a method.

This must be overridden by the specific fetcher class.

$priority = $self->priority();

$priority = WWW::FetchStory::Fetcher::priority($class);

=cut

sub priority {
    my $class = shift;

    return 1;
} # priority

=head2 allow

If this fetcher can be used for the given URL, then this returns
true.
This must be overridden by the specific fetcher class.

    if ($obj->allow($url))
    {
	....
    }

=cut

sub allow {
    my $self = shift;
    my $url = shift;

    return ($url =~ /owl\.tauri\.org/);
} # allow

=head1 Private Methods

=head2 tidy

Remove the extraneous formatting from the fetched content.

    $content = $self->tidy(content=>$content,
			   title=>$title);

=cut

sub tidy {
    my $self = shift;
    my %args = (
	content=>'',
	title=>'',
	@_
    );

    my $content = $args{content};
    my $story = '';
    my $title = '';
    if ($content =~ m#<title>OWL\s*::\s*([^<]+)</title>#)
    {
	$title = $1;
    }
    else
    {
	$title = $args{title};
    }

    if ($content =~ m#<div class=pagehead></div>(.*?)<div align=left><span class=credits>#s)
    {
	$story = $1;
    }
    elsif ($content =~ m#<body[^>]*>(.*)</body>#is)
    {
	$story = $1;
    }

    if ($story)
    {
	$story = $self->tidy_chars($story);
    }
    else
    {
	$story = $content;
    }

    my $out = '';
    $out .= "<html>\n";
    $out .= "<head>\n";
    $out .= "<title>$title</title>\n";
    $out .= "</head>\n";
    $out .= "<body>\n";
    $out .= "$story\n";
    $out .= "</body>\n";
    $out .= "</html>\n";
    return $out;
} # tidy
=head2 parse_toc

Parse the table-of-contents file.

    %info = $self->parse_toc(content=>$content,
			 url=>$url);

This should return a hash containing:

=over

=item chapters

An array of URLs for the chapters of the story.  (In the case where the
story only takes one page, that will be the chapter).

=item title

The title of the story.

=back

It may also return additional information, such as Summary.

=cut

sub parse_toc {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my %info = ();
    my $content = $args{content};
    my @chapters = ();
    $info{url} = $args{url};
    my $sid='';
    if ($args{url} =~ m#psid=(\d+)#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }

    if ($content =~ m#<title>OWL\s*::\s*([^<]+)</title>#)
    {
	$info{title} = $1;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
    }

    if ($content =~ m#by <a href="users.php\?uid=\d+">([^<]+)</a>#s)
    {
	$info{author} = $1;
    }
    else
    {
	$info{author} = $self->parse_author(%args);
    }

    if ($content =~ m#<span class=summary>([^<]+)</span>#s)
    {
	$info{summary} = $1;
    }
    if ($content =~ m#Characters:\s*([^<]+)\s*<br>#s)
    {
	$info{characters} = $1;
    }

    # Owl does not have a sane chapter system
    my $fmt = 'http://owl.tauri.org/stories.php?sid=%d&action=print';
    while ($content =~ m#stories.php\?sid=(\d+)#sg)
    {
	my $ch_sid = $1;
	my $ch_url = sprintf($fmt, $ch_sid);
	warn "chapter=$ch_url\n" if $self->{verbose};
	push @chapters, $ch_url;
    }
    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::Owl
__END__
