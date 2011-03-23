package WWW::FetchStory::Fetcher::FanfictionNet;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::FanfictionNet - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the FanfictionNet story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head2 info

Information about the fetcher.

$info = $self->info();

=cut

sub info {
    my $self = shift;
    
    my $info = "(http://www.fantiction.net/) Huge fan fiction archive.";

    return $info;
} # info

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic FanfictionNet fetcher, and then refinements for particular
FanfictionNet community, such as the sshg_exchange community.
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

    return ($url =~ /fanfiction\.net/);
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

    my $category = '';
    my $subcat = '';
    my $title = $args{title};
    if ($content =~ m#<a href='/cat/\d+/'>([^<]+)</a>[\s\d;&\#]+<a href[^>]+>([^<]+)</a>[\s\d;&\#]+<b>([^<]+)</b>#s)
    {
	$category = $1;
	$subcat = $2;
	$title = $3;
    }
    elsif ($content =~ m!^<td><a href=[^>]+>([^<]+)</a>\s+&#187;\s+<a href=[^>]+>([^<]+)</a>\s+&#187;\s+<b>([^<]+)</b></td>!m)
    {
	$category = $1;
	$subcat = $2;
	$title = $3;
    }
    elsif ($content =~ m!"/book/Harry_Potter/">([^<]+)</a>.*?<b>([^<]+)</b>!s)
    {
	$category = $1;
	$title = $2;
    }
    warn "category=$category\n" if $self->{verbose};
    warn "subcat=$subcat\n" if $self->{verbose};
    warn "title=$title\n" if $self->{verbose};

    my $summary = '';
    if ($content =~ m!var summary = '(.*?)';!m)
    {
	$summary = $1;
    }

    my $author = '';
    if ($content =~ m!Author: <a href[^>]+>([^<]+)</a>!s)
    {
	$author = $1;
    }
    elsif ($content =~ m!<a href='/u/\d+/[^>]+>([^<]+)</a>!s)
    {
	$author = $1;
    }
    elsif ($content =~ m!var author = '([^\']+)';!m)
    {
	$author = $1;
    }
    $author =~ s/^\s*//;
    $author =~ s/\s*$//;
    warn "author=$author\n" if $self->{verbose};

    $content =~ m#- English - ([^-<]+) -#s;
    my $p1 = $1;
    $content =~ m#(Published:[^<]+)#s;
    my $p2 = $1;
    my $para = "$p1 $p2";
    warn "para=$para\n" if $self->{verbose};

    my $chapter = $self->parse_ch_title(%args);
    warn "chapter=$chapter\n" if $self->{verbose};

    my $story = '';
    if ($content =~ m#<div id=storytext class=storytext>(.*?)</div>#s)
    {
	$story = $1;
    }
    elsif ($content =~ m#</TD></form></TR></TABLE>\s*<div[^>]*>(.*?)</div>#is)
    {
	my $story_start = $1;
	my @stuff = split('</div>', $story_start);
	$story = shift @stuff;
	$story =~ s/^\s*//;
	$story =~ s#<SCRIPT.*</script>##is;
    }
    elsif ($content =~ m#<!-- start story -->(.*)<!-- end story -->#s)
    {
	$story = $1;
    }

    if ($story)
    {
	$story = $self->tidy_chars($story);
    }

    my $story_title = "$title: $chapter";
    $story_title = $title if ($title eq $chapter);
    $story_title = $title if ($chapter eq '');

    my $out = '';
    if ($story)
    {
	$out .= "<html>\n";
	$out .= "<head>\n";
	$out .= "<title>$story_title</title>\n";
	$out .= "</head>\n";
	$out .= "<body>\n";
	$out .= "<h1>$story_title</h1>\n";
	$out .= "<p>by $author</p>\n";
	$out .= "<p>$category $subcat ";
	$out .= "<br/>\n<b>Summary:</b> $summary<br/>\n" if $summary;
	$out .= "$para</p>\n";
	$out .= "<div>\n";
	$out .= "$story\n";
	$out .= "</div>\n";
	$out .= "</body>\n";
	$out .= "</html>\n";
    }
    return (
	html=>$out,
	story=>$story,
    );
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
    if ($args{url} =~ m#http://www.fanfiction.net/s/(\d+)/#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }
    if ($content =~ m/&#187; <b>([^<]+)<\/b>/s)
    {
	$info{title} = $1;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
    }
    my $auth_url = '';
    if ($content =~ m#<a href='(/u/\d+/\w+)'>([^<]+)</a>#s)
    {
	$auth_url = $1;
	$info{author} = $2;
    }
    else
    {
	$info{author} = $self->parse_author(%args);
    }
    # the summary is on the Author page!
    if ($auth_url && $sid)
    {
	my $auth_page = $self->get_page("http://www.fanfiction.net${auth_url}");
	if ($auth_page =~ m#<a href="/s/${sid}/\d+/[-\w]+">.*?<div\s*class='[-\w\s]+'>([^<]+)<div#s)
	{
	    $info{summary} = $1;
	}
	elsif ($auth_page =~ m#<a class=reviews href='/r/${sid}/'>reviews</a>\s*<div class='z-indent z-padtop'>([^<]+)<div#s)
	{
	    $info{summary} = $1;
	}
	else
	{
	    $info{summary} = $self->parse_summary(%args);
	}
    }
    else
    {
	$info{summary} = $self->parse_summary(%args);
    }
    $info{characters} = '';
    # fortunately fanfiction.net has a sane-ish chapter system
    # find the chapter from the chapter selection form
    if ($content =~ m#<SELECT title='chapter\snavigation'\sName=chapter(.*?)</select>#is)
    {
	my $ch_select = $1;
	if ($ch_select =~ m/<option\s*value=(\d+)\s*>[^<]+$/s)
	{
	    my $num_ch = $1;
	    my $fmt = $args{url};
	    $fmt =~ s!/\d+/\d+/!/%d/\%d/!;
	    for (my $i=1; $i <= $num_ch; $i++)
	    {
		my $ch_url = sprintf($fmt, $sid, $i);
		warn "chapter=$ch_url\n" if $self->{verbose};
		push @chapters, $ch_url;
	    }
	}
	else
	{
	    warn "ch_select=$ch_select";
	    @chapters = ($args{url});
	}
    }
    else # only one chapter
    {
	@chapters = ($args{url});
    }

    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

=head2 parse_ch_title

Get the chapter title from the content

=cut
sub parse_ch_title {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $title = '';
    if ($content =~ m#<option[^>]+selected>([^<]+)</option>#s)
    {
	$title = $1;
    }
    elsif ($content =~ m#<SELECT title='chapter navigation'.*?<option[^>]+selected>([^<]+)<#s)
    {
	$title = $1;
    }
    else
    {
	$title = $self->parse_title(%args);
    }
    $title =~ s/<u>//ig;
    $title =~ s/<\/u>//ig;
    return $title;
} # parse_ch_title

1; # End of WWW::FetchStory::Fetcher::FanfictionNet
__END__
