package WWW::FetchStory::Fetcher::FictionAlley;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::FictionAlley - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the FictionAlley story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head1 METHODS

=head2 new

$obj->WWW::FetchStory::Fetcher->new();

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    # disable the User-Agent for FictionAlley
    # because it blocks wget
    $self->{wget} .= " --user-agent=''";

    return ($self);
} # new

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic FictionAlley fetcher, and then refinements for particular
FictionAlley community, such as the sshg_exchange community.
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

    return ($url =~ /fictionalley/);
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
    my $story_title = '';
    if ($content =~ m#<title>Astronomy Tower -\s+(.*?)</title>#)
    {
	$story_title = $1;
    }
    elsif ($content =~ m#<title>\w+ -\s+(.*?)</title>#)
    {
	$story_title = $1;
    }
    elsif ($content =~ m#<title>(.*?)</title>#)
    {
	$story_title = $1;
    }
    if ($content =~ m#<!-- headerstart -->(.*?)<!-- footerstart -->#s)
    {
	$story = $1;
    }
    if ($story)
    {
	$story = $self->tidy_chars($story);
    }
    else
    {
	return $content;
    }
    warn "title=$story_title\n" if $self->{verbose};

    my $out = <<EOT;
<html>
<head>
<title>$story_title</title>
</head>
<body>
<h1>$story_title</h1>
$story
</body>
</html>
EOT
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
    if ($content =~ m/<h1\s*class\s*=\s*"title"[^>]*>([^<]+)\s*by\s*<a/s)
    {
	$info{title} = $1;
	$info{title} =~ s/&#039;/'/g;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
    }
    if ($content =~ m/<h1\s*class\s*=\s*"title"[^>]*>[^<]+\s*by\s*<a href="[^"]+">([^<]+)<\/a>/s)
    {
	$info{author} = $1;
    }
    else
    {
	$info{author} = $self->parse_author(%args);
    }
    if ($content =~ /<div class="summary"[^>]*>[\w\s]*<br \/>\s*<i>\s*(.*?)<\/i>\s*<\/div>/s)
    {
	$info{summary} = $1;
    }
    else
    {
	$info{summary} = $self->parse_summary(%args);
    }
    $info{characters} = '';
    $info{universe} = 'Harry Potter';
    while ($content =~ m#<a href\s*=\s*"(http://www.fictionalley.org/authors/\w+/\w+\.html)"\s*class\s*=\s*"chapterlink">#g)
    {
	my $ch_url = $1;
	warn "chapter=$ch_url\n" if $self->{verbose};
	push @chapters, $ch_url;
    }

    $info{chapters} = \@chapters;
    warn "WARNING: this interface is incomplete.";

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::FictionAlley
__END__
