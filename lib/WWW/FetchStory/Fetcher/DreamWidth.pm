package WWW::FetchStory::Fetcher::DreamWidth;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::DreamWidth - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the DreamWidth story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head1 METHODS

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic DreamWidth fetcher, and then refinements for particular
DreamWidth community, such as the sshg_exchange community.
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

    return ($url =~ /\.dreamwidth\.org/);
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

    my $user= '';
    my $title = '';
    my $url = '';
    if ($content =~ m#<title>([\w]+):\s*([^<]+)</title>#s)
    {
	$user= $1;
	$title = $2;
    }
    elsif ($content =~ m#<title>([^<]+)</title>#s)
    {
	$title = $1;
    }
    if ($content =~ m#([-\w]+)</b></a></span>\) wrote in <span class='ljuser'#s)
    {
	$user = $1;
    }

    my $year = '';
    my $month = '';
    my $day = '';
    if ($content =~ m#wrote,<br /><font[^>]+>\@\s*<a href="[^"]+">(\d+)</a>-<a href="[^"]+">(\d+)</a>-<a href="[^"]+">(\d+)</a>#s)
    {
	$year = $1;
	$month = $2;
	$day = $3;
	warn "year=$year,month=$month,day=$day\n" if $self->{verbose};
    }

    if (!$url)
    {
	if ($content =~ m#<a[^>]*href=["']([^?\s]+)\?mode=reply["']\s*>Post a new comment#s)
	{
	    $url = $1;
	}
	elsif ($content =~ m#<a[^>]*href=["']([^?\s]+)\?mode=reply#s)
	{
	    $url = $1;
	}
	elsif ($content =~ m#<a[^>]*href="([^?\s]+)"\s*>Link</a>#s)
	{
	    $url = $1;
	}
    }
    if (!$user && $url && ($url =~ m#http://([-\w]+)\.dreamwidth\.org#s))
    {
	$user = $1;
    }

    my $story = '';
    if ($content =~ m#<div id='entrysubj'>(.*?)<div id='Comments'>#s)
    {
	$story = $1;
    }
    elsif ($content =~ m#<div class="entry"[^>]*>(.*?)<div class="tag">#s)
    {
	$story = $1;
    }
    warn "user=$user, title=$title\n" if $self->{verbose};
    warn "url=$url\n" if $self->{verbose};
    if ($story)
    {
	$story = $self->tidy_chars($story);
	# remove cutid1
	$story =~ s#<a name="cutid."></a>##sg;
    }
    else
    {
	print STDERR "story not found\n";
	return $self->tidy_chars($content);
    }

    my $out = <<EOT;
<html>
<head>
<title>$title</title>
</head>
<body>
<h1>$title</h1>
<p>by $user</p>
<p>$year-$month-$day (from <a href='$url'>here</a>)</p>
<p>$story
</body>
</html>
EOT
    return $out;
} # tidy

=head2 get_toc

Get a table-of-contents page.

=cut
sub get_toc {
    my $self = shift;
    my $url = shift;

    return $self->get_page("${url}?format=light");
} # get_toc

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

    my $content = $args{content};
    my $user = '';
    my $is_community = 0;
    if ($args{url} =~ m{http://([-\w]+)\.dreamwidth\.org})
    {
	$user = $1;
    }
    if ($user eq 'community')
    {
	$is_community = 1;
	$user = '';
	if ($args{url} =~ m{http://community\.dreamwidth\.org/([-\w]+)})
	{
	    $user = $1;
	}
    }

    my %info = ();
    $info{url} = $args{url};

    my @chapters = ("$args{url}?format=light");
    $info{toc_first} = 1;

    my $title = $self->parse_title(%args);
    $title =~ s/${user}:\s*//;
    $info{title} = $title;

    my $summary = $self->parse_summary(%args);
    $summary =~ s/"/'/g;
    $info{summary} = $summary;

    my $author = $self->parse_author(%args);
    if (!$author) 
    {
	$author = $user;
    }
    $info{author} = $author;

    my $characters = $self->parse_characters(%args);
    $info{characters} = $characters;

    if ($user)
    {
	warn "user=$user\n" if $self->{verbose};
	if ($is_community)
	{
	    while ($content =~
		m/href="(http:\/\/community\.dreamwidth\.org\/${user}\/\d+.html)(#cutid\d)?">/sg)
	    {
		my $ch_url = $1;
		if ($ch_url ne $args{url})
		{
		    warn "chapter=$ch_url\n" if $self->{verbose};
		    push @chapters, "${ch_url}?format=light";
		}
	    }
	}
	else
	{
	    while ($content =~
		m/href="(http:\/\/${user}\.dreamwidth\.org\/\d+.html)(#cutid\d)?">/sg)
	    {
		my $ch_url = $1;
		if ($ch_url ne $args{url})
		{
		    warn "chapter=$ch_url\n" if $self->{verbose};
		    push @chapters, "${ch_url}?format=light";
		}
	    }
	}
    }
    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::DreamWidth
__END__
