package WWW::FetchStory::Fetcher::TardisBigBang3;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::TardisBigBang3 - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the TardisBigBang3 story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.

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

    return ($url =~ /www\.tardisbigbang\.com\/Round3/);
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
    my $title = $args{title};
    my $story = '';
    if ($content =~ m#<div class="main">(.*?)</div>\s*<p class="bottomcomment">#s)
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
    if ($args{url} =~ m#storyID=(S\d+)#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }
    if ($content =~ m#<p id="authorinfo">by <strong>([^<]+)</strong>#)
    {
	$info{author} = $1;
    }
    else
    {
	$info{author} = $self->parse_author(%args);
    }
    if ($content =~ m#<h2>([^<]+)</h2>#)

    {
	$info{title} = $1;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
    }
    if ($content =~ m#<p class="summary">(.*?)</p>#)
    {
	$info{summary} = $1;
    }
    else
    {
	$info{summary} = $self->parse_summary(%args);
    }
    if ($content =~ m#<span class="storyinfo">([\w\s]+) \| ([\w-]+) \| (.*?) \| ([\d,]+) words</span>#)
    {
	$info{universe} = $1;
	$info{rating} = $2;
	$info{summary2} = $3;
	$info{size} = $4;

	$info{size} =~ s/,//g;
	$info{size} .= 'w';
	$info{universe} =~ s/New Who/Doctor Who/;
    }
    else
    {
	$info{universe} = 'Doctor Who';
    }

    if ($content =~ m#part=2#)
    {
	my $fmt = $args{url};
	$fmt =~ s/part=\d+/part=\%d/;
	while ($content =~ m#storyID=${sid}\&part=(\d+)">Part#sg)
	{
	    my $ch_num = $1;
	    my $ch_url = sprintf($fmt, $ch_num);
	    warn "chapter=$ch_url\n" if $self->{verbose};
	    push @chapters, $ch_url;
	}
    }
    else
    {
	push @chapters, $args{url};
    }

    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::TardisBigBang3
__END__
