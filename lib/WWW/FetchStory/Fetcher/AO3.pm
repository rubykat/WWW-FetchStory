package WWW::FetchStory::Fetcher::AO3;

use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::AO3 - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the AO3 story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head1 METHODS

=head2 info

Information about the fetcher.

$info = $self->info();

=cut

sub info {
    my $self = shift;
    
    my $info = "http://www.archiveofourown.org AO3 General fanfic archive";

    return $info;
} # info

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic AO3 fetcher, and then refinements for particular
AO3 community, such as the sshg_exchange community.
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

    return ($url =~ /archiveofourown\.org/ || $url =~ /ao3\.org/);
} # allow

=head1 Private Methods

=head2 parse_toc

Parse the table-of-contents file.

    %info = $self->parse_toc(content=>$content,
			 url=>$url,
			 urls=>\@urls);

This should return a hash containing:

=over

=item chapters

An array of URLs for the chapters of the story.  In the case where the
story only takes one page, that will be the chapter.
In the case where multiple URLs have been passed in, it will be those URLs.

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
    my %info = ();
    $info{url} = $args{url};

    my $sid='';
    if ($args{url} =~ m#archiveofourown.org/works/(\d+)#)
    {
	$sid = $1;
    }
    else
    {
	print STDERR "did not find SID for $args{url}";
	return $self->SUPER::parse_toc(%args);
    }

    $info{title} = $self->parse_title(%args);
    $info{author} = $self->parse_author(%args);
    $info{summary} = $self->parse_summary(%args);
    $info{characters} = $self->parse_characters(%args);
    $info{universe} = $self->parse_universe(%args);
    $info{category} = $self->parse_category(%args);
    $info{rating} = $self->parse_rating(%args);
    $info{chapters} = $self->parse_chapter_urls(%args, sid=>$sid);
    my $epub_url = $self->parse_epub_url(%args, sid=>$sid);
    if ($epub_url)
    {
        $info{epub_url} = $epub_url;
    }
    if ($info{epub_url})
    {
        $info{wordcount} = $self->parse_wordcount(%args);
    }

    return %info;
} # parse_toc

=head2 parse_chapter_urls

Figure out the URLs for the chapters of this story.

=cut
sub parse_chapter_urls {
    my $self = shift;
    my %args = (
	urls=>undef,
	content=>'',
	@_
    );
    my $content = $args{content};
    my $sid = $args{sid};
    my @chapters = ();
    if (defined $args{urls})
    {
	@chapters = @{$args{urls}};
    }
    if (@chapters == 1
	    and $content =~ m!href="(/downloads/$sid/[^.]+\.html)!)
    {
	@chapters = ("http://archiveofourown.org$1");
    }

    return \@chapters;
} # parse_chapter_urls

=head2 parse_epub_url

Figure out the URL for the EPUB version of this story.

=cut
sub parse_epub_url {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );
    my $content = $args{content};
    my $sid = $args{sid};
    my $epub_url = '';
    if ($content =~ m!href="(/downloads/$sid/[^.]+\.epub)!)
    {
	$epub_url = ("http://archiveofourown.org$1");
    }

    return $epub_url;
} # parse_epub_url

=head2 parse_title

Get the title.

=cut
sub parse_title {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $title = '';
    if ($content =~ m!<h2 class="title heading">\s*([^<]*)</h2>!s)
    {
	$title = $1;
        $title =~ s/\s*$//s; # remove any trailing whitespace
    }
    elsif ($content =~ m!<h1>([^<]*)</h1>!)
    {
	$title = $1;
    }
    else
    {
	$title = $self->SUPER::parse_title(%args);
    }
    return $title;
} # parse_title

=head2 parse_author

Get the author.

=cut
sub parse_author {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $author = '';
    if ($content =~ m! href="/users/\w+/pseuds/\w+">([^<]+)</a>!)
    {
	$author = $1;
    }
    else
    {
	$author = $self->SUPER::parse_author(%args);
    }
    $author =~ s/_/ /g;
    return $author;
} # parse_author

=head2 parse_summary

Get the summary.

=cut
sub parse_summary {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $summary = '';
    if ($content =~ m!<h3[^>]*>Summary:</h3>\s*<blockquote class="userstuff"><p>([^<]+)</p></blockquote>!s)
    {
        # This is a single-paragraph summary.
	$summary = $1;
    }
    elsif ($content =~ m!<h3[^>]*>Summary:</h3>\s*<blockquote class="userstuff">(.*?)</blockquote>!s)
    {
        # This is a multi-paragraph summary, it needs to be tidied up.
	$summary = $1;
        $summary =~ s!<p>!!g;
        $summary =~ s!</p>!!g;
        $summary =~ s/^\s*//;
        $summary =~ s/\s*$//;
    }
    else
    {
	$summary = $self->SUPER::parse_summary(%args);
    }
    # AO3 tends to have messy HTML stuff stuck in the summary
    $summary =~ s!&lt;[a-zA-Z]&gt;!!g;
    $summary =~ s!&lt;/[a-zA-Z]&gt;!!g;
    $summary =~ s!&amp;!and!g;
    $summary =~ s!<[^>]+>!!g;
    $summary =~ s!</[^>]+>!!g;
    $summary =~ s!&#x27;!'!g;
    $summary =~ s!&#39;!'!g;
    return $summary;
} # parse_summary

=head2 parse_wordcount

Get the wordcount.

=cut
sub parse_wordcount {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $words = '';
    if ($content =~ m!\((\d+) words\)!m)
    {
	$words = $1;
    }
    elsif ($content =~ m!<dt class="words">Words:</dt><dd class="words">(\d+)</dd>!)
    {
	$words = $1;
    }
    return $words;
} # parse_wordcount

=head2 parse_characters

Get the characters.

=cut
sub parse_characters {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $characters = '';
    if ($content =~ m!<dd class="character tags">(.*?)</dd>!s)
    {
        # multiple characters inside links
        my $str = $1;
        my @chars = ();
        while ($str =~ m!([^><]+)</a>!g)
        {
            push @chars, $1;
        }
        $characters = join(', ', @chars);
    }
    elsif ($content =~ m!^Characters: (.*?)$!m)
    {
	$characters = $1;
    }
    else
    {
	$characters = $self->SUPER::parse_characters(%args);
    }
    # Remove the (Universe) part of the characters
    $characters =~ s!\s*\([^)]+\)!!g;

    # Specific character things to change
    $characters =~ s!James "Bucky" Barnes!James Barnes!g;
    $characters =~ s!James "Rhodey" Rhodes!James Rhodes!g;
    $characters =~ s!You!U!g;
    $characters =~ s!Dummy!Dum-E!g;
    
    return $characters;
} # parse_characters

=head2 parse_universe

Get the universe.

=cut
sub parse_universe {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $universe = '';
    if ($content =~ m!<dd class="fandom tags">(.*?)</dd>!s)
    {
        # multiple fandoms inside links
        my $str = $1;
        my @univ = ();
        while ($str =~ m!([^><]+)</a>!g)
        {
            push @univ, $1;
        }
        $universe = join(', ', @univ);
    }
    else
    {
	$universe = $self->SUPER::parse_universe(%args);
    }
    # Minor adjustments to AO3 tags
    if ($universe =~ m!Harry Potter - J\. K\. Rowling!)
    {
        $universe =~ s/\s*-\s*J\. K\. Rowling//;
    }
    elsif ($universe =~ m!(Doctor Who)!)
    {
        $universe = $1;
    }
    elsif ($universe =~ m!Blake&amp;#39;s 7!)
    {
        $universe = 'Blakes 7';
    }
    elsif ($universe =~ m!(Marvel Cinematic Universe|Avengers|Iron Man|Captain America)!)
    {
        $universe = 'MCU';
    }
    return $universe;
} # parse_universe

=head2 parse_category

Get the category.

=cut
sub parse_category {
    my $self = shift;
    my %args = @_;

    my $content = $args{content};

    my $category = '';
    if ($content =~ m!<dd class="freeform tags">(.*?)</dd>!s)
    {
        # multiple categories inside links
        my $str = $1;
        my @cats = ();
        while ($str =~ m!([^><]+)</a>!g)
        {
            push @cats, $1;
        }
        $category = join(', ', @cats);
    }
    elsif ($content =~ m!Additional Tags:\s*</dt>\s*<dd class="freeform tags">\s*<ul[^>]*>\s*(.*?)\s*</ul>!s)
    {
	my $categories = $1;
	my @cats = split(/<li>/, $categories);
	my @categories = ();
	foreach my $cat (@cats)
	{
	    if ($cat =~ m!class="tag">([^<]+)</a>!)
	    {
		push @categories, $1;
	    }
	}
	$category = join(', ', @categories);
    }
    else
    {
	$category = $self->SUPER::parse_category(%args);
    }

    # Also add the "relationship tags", if any, to the categories
    if ($content =~ m!<dd class="relationship tags">(.*?)</dd>!s)
    {
        my $str = $1;
        my @cats = ($category);
        while ($str =~ m!([^><]+)</a>!g)
        {
            my $rawrel = $1;
            my $rel = $rawrel;
            if ($rawrel =~ m!/!)
            {
                $rawrel =~ s!/!-!g;
                $rel = "${rawrel} Romance";
            }
            elsif ($rawrel =~ m!\&amp;!)
            {
                $rawrel =~ s!\s*\&amp;\s*!-!g;
                $rel = "${rawrel} Friendship";
            }
            $rel =~ s!\s*\([^)]+\)!!g; # remove universe if there is one there
            $rel =~ s!James "Bucky" Barnes!James Barnes!g;
            $rel =~ s!James "Rhodey" Rhodes!James Rhodes!g;
            $rel =~ s!You!U!g;
            $rel =~ s!Dummy!Dum-E!g;
            push @cats, $rel;
        }
        $category = join(', ', @cats);
    }

    return $category;
} # parse_category

1; # End of WWW::FetchStory::Fetcher::AO3
__END__
