package WWW::FetchStory::Fetcher;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the base class for story-fetching plugins for WWW::FetchStory.

=cut

require File::Temp;
use Date::Format;
use Encode::ZapCP1252;
use HTML::Entities;
use HTML::Strip;
use HTML::Tidy::libXML;
use EBook::EPUB;
use YAML::Any;

=head1 METHODS

=head2 new

$obj->WWW::FetchStory::Fetcher->new();

=cut

sub new {
    my $class = shift;
    my %parameters = @_;
    my $self = bless ({%parameters}, ref ($class) || $class);

    $self->{wget} = 'wget';
    if (-f "$ENV{HOME}/cookies.txt")
    {
	$self->{wget} .= " --load-cookies $ENV{HOME}/cookies.txt";
    }
    $self->{stripper} = HTML::Strip->new();
    $self->{stripper}->add_striptag("head");

    return ($self);
} # new

=head2 name

The name of the fetcher; this is basically the last component
of the module name.  This works as either a class function or a method.

$name = $self->name();

$name = WWW::FetchStory::Fetcher::name($class);

=cut

sub name {
    my $class = shift;
    
    my $fullname = (ref ($class) ? ref ($class) : $class);

    my @bits = split('::', $fullname);
    return pop @bits;
} # name

=head2 info

Information about the fetcher.
By default this just returns the formatted name.

$info = $self->info();

=cut

sub info {
    my $self = shift;
    
    my $name = $self->name();

    # split the name into words
    my $info = $name;
    $info =~ s/([A-Z])/ $1/g;
    $info =~ s/^\s+//;

    return $info;
} # info

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic LiveJournal fetcher, and then refinements for particular
LiveJournal community, such as the sshg_exchange community.
This works as either a class function or a method.

This must be overridden by the specific fetcher class.

$priority = $self->priority();

$priority = WWW::FetchStory::Fetcher::priority($class);

=cut

sub priority {
    my $class = shift;
    return 0;
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

    return 0;
} # allow

=head2 fetch

Fetch the story, with the given options.

    %story_info = $obj->fetch(
	url=>$url,
	basename=>$basename,
	toc=>0);

=over

=item basename

Optional basename used to construct the filenames.
If this is not given, the basename is derived from the title of the story.

=item toc

Build a table-of-contents file if this is true.

=item url

The URL of the story.  The page is scraped for meta-information about the story,
including the title and author.  Site-specific Fetcher plugins can find additional
information, including the URLs of all the chapters in a multi-chapter story.

=back

=cut

sub fetch {
    my $self = shift;
    my %args = (
	url=>'',
	basename=>'',
	@_
    );

    $self->{verbose} = $args{verbose};

    my $toc_content = $self->get_toc($args{url});
    my %story_info = $self->parse_toc(content=>$toc_content,
				      url=>$args{url});
    my $now = time2str('%Y-%m-%d %H:%M', time);
    $story_info{fetched} = $now;

    warn Dump(\%story_info) if $self->{verbose};

    my @ch_urls = @{$story_info{chapters}};
    my $one_chapter = (@ch_urls == 1);
    my $first_chapter_is_toc = $story_info{toc_first};
    my $basename = ($args{basename}
		    ? $args{basename}
		    : $self->get_story_basename($story_info{title}));
    $story_info{basename} = $basename;
    my @storyfiles = ();
    my @ch_titles = ();
    my @ch_wc = ();
    my $count = (($one_chapter or $first_chapter_is_toc) ? 0 : 1);
    foreach (my $i = 0; $i < @ch_urls; $i++)
    {
	my $ch_title = sprintf("%s (%d)", $story_info{title}, $i+1);
	my %ch_info = $self->get_chapter(base=>$basename,
				    count=>$count,
				    url=>$ch_urls[$i],
				    title=>$ch_title);
	push @storyfiles, $ch_info{filename};
	push @ch_titles, $ch_info{title};
	push @ch_wc, $ch_info{wordcount};
	$story_info{wordcount} += $ch_info{wordcount};
	$count++;
    }

    $story_info{storyfiles} = \@storyfiles;
    $story_info{chapter_titles} = \@ch_titles;
    $story_info{chapter_wc} = \@ch_wc;
    if ($args{toc} and !$args{epub}) # build a table-of-contents
    {
	my $toc = $self->build_toc(info=>\%story_info);
	unshift @{$story_info{storyfiles}}, $toc;
	unshift @{$story_info{chapter_titles}}, "Table of Contents";
    }
    if ($args{epub})
    {
	my $epub = $self->build_epub(info=>\%story_info);
    }

    return %story_info;
} # fetch

=head1 Private Methods

=head2 get_story_basename

Figure out the file basename for a story by using its title.

    $basename = $self->get_story_basename($title);

=cut
sub get_story_basename {
    my $self = shift;
    my $title = shift;

    # make a word with only letters and numbers
    # and with everything lowercase
    # and then the spaces replaced with underscores
    my $base = $title;
    $base =~ s/^The\s+//; # get rid of leading "The "
    $base =~ s/^A\s+//; # get rid of leading "A "
    $base =~ s/^An\s+//; # get rid of leading "An "
    $base =~ s/-/ /g; # replace dashes with spaces
    $base =~ s/[^\w\s]//g;
    $base = lc($base);
    my @words = split(' ', $base);
    my @first_words = ();
    my $max_words = 3;
    for (my $i = 0; $i < @words and @first_words < $max_words; $i++)
    {
	# also skip little words
	if ($words[$i] =~ /^(the|a|an|and)$/)
	{
	}
	elsif (@first_words >= 2 and $words[$i] =~ /^(of|and|to|in)$/)
	{
	    # if the third word is a little word, forget it
	    last;
	}
	else
	{
	    push @first_words, $words[$i];
	}
    }

    return join('_', @first_words);

} # get_story_basename

=head2 extract_story

Extract the story-content from the fetched content.

    my ($story, $title) = $self->extract_story(content=>$content,
	title=>$title);

=cut

sub extract_story {
    my $self = shift;
    my %args = (
	content=>'',
	title=>'',
	@_
    );

    my $story = '';
    my $title = '';
    if ($args{content} =~ m#<title>([^<]+)</title>#is)
    {
	$title = $1;
    }
    else
    {
	$title = $args{title};
    }

    if ($args{content} =~ m#<body[^>]*>(.*)</body>#is)
    {
	$story = $1;
    }
    elsif ($args{content} =~ m#</head>(.*)#is)
    {
	$story = $1;
    }

    if ($story)
    {
	$story = $self->tidy_chars($story);
    }
    else
    {
	$story = $args{content};
    }

    return ($story, $title);

} # extract_story

=head2 make_css

Create site-specific CSS styling.

    $css = $self->make_css();

=cut

sub make_css {
    my $self = shift;

    return '';
} # make_css

=head2 tidy

Make a tidy, compliant XHTML page from the given story-content.

    $content = $self->tidy(story=>$story,
			   title=>$title);

=cut

sub tidy {
    my $self = shift;
    my %args = (
	story=>'',
	title=>'',
	@_
    );

    my $story = $args{story};
    my $title = $args{title};
    my $css = $self->make_css(%args);

    my $html = '';
    $html .= "<html>\n";
    $html .= "<head>\n";
    $html .= "<title>$title</title>\n";
    $html .= $css if $css;
    $html .= "</head>\n";
    $html .= "<body>\n";
    $html .= "$story\n";
    $html .= "</body>\n";
    $html .= "</html>\n";

    my $tidy = HTML::Tidy::libXML->new();
    my $xhtml = $tidy->clean($html, 'utf8', 1);

    # fixing an error
    $xhtml =~ s!xmlns="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml"!xmlns="http://www.w3.org/1999/xhtml"!;

    return $xhtml;
} # tidy

=head2 get_toc

Get a table-of-contents page.

=cut
sub get_toc {
    my $self = shift;
    my $url = shift;

    return $self->get_page($url);
} # get_toc

=head2 get_page

Get the contents of a URL.

=cut

sub get_page {
    my $self = shift;
    my $url = shift;

    warn "getting $url\n" if $self->{verbose};
    my $content = '';
    my $cmd = sprintf("%s -O %s '%s'", $self->{wget}, '-', $url);
    warn "$cmd\n" if $self->{verbose};
    my $ifh;
    open($ifh, "${cmd}|") or die "FAILED $cmd: $!";
    while(<$ifh>)
    {
	$content .= $_;
    }
    close($ifh);

    return $content;
} # get_page

=head2 parse_toc

Parse the table-of-contents file.

This must be overridden by the specific fetcher class.

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
    my @chapters = ($args{url});
    $info{url} = $args{url};
    $info{title} = $self->parse_title(%args);
    $info{author} = $self->parse_author(%args);
    $info{summary} = $self->parse_summary(%args);
    $info{characters} = $self->parse_characters(%args);
    $info{universe} = $self->parse_universe(%args);
    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

=head2 parse_title

Get the title from the content

=cut
sub parse_title {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $title = '';
    if ($content =~ /<(?:b|strong)>Title:?\s*<\/(?:b|strong)>:?\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$title = $1;
    }
    elsif ($content =~ /\bTitle:\s*"?(.*?)"?\s*<br/s)
    {
	$title = $1;
    }
    elsif ($content =~ m#<h1>([^<]+)</h1>#is)
    {
	$title = $1;
    }
    elsif ($content =~ m#<h2>([^<]+)</h2>#is)
    {
	$title = $1;
    }
    elsif ($content =~ m#<h3>([^<]+)</h3>#is)
    {
	$title = $1;
    }
    elsif ($content =~ m#<h4>([^<]+)</h4>#is)
    {
	$title = $1;
    }
    elsif ($content =~ m#<title>([^<]+)</title>#is)
    {
	$title = $1;
    }
    $title =~ s/<u>//ig;
    $title =~ s/<\/u>//ig;
    return $title;
} # parse_title

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
    if ($content =~ /Chapter \d+[:.]?\s*([^<]+)/si)
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

=head2 parse_author

Get the author from the content

=cut
sub parse_author {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $author = '';
    if ($content =~ /<(?:b|strong)>Author:?\s*<\/(?:b|strong)>:?\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$author = $1;
    }
    elsif ($content =~ /\bAuthor:\s*"?(.*?)"?\s*<br/si)
    {
	$author = $1;
    }
    elsif ($content =~ /<meta name="author" content="(.*?)"/si)
    {
	$author = $1;
    }
    elsif ($content =~ /<p>by (.*?)<br/si)
    {
	$author = $1;
    }
    return $author;
} # parse_author

=head2 parse_summary

Get the summary from the content

=cut
sub parse_summary {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $summary = '';
    if ($content =~ /<(?:b|strong)>Summary:?\s*<\/(?:b|strong)>:?\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$summary = $1;
    }
    elsif ($content =~ m#<i>Summary:</i>\s*([^<]+)\s*<br>#s)
    {
	$summary = $1;
    }
    elsif ($content =~ /<i>Summary:<\/i>\s*(.*?)\s*$/m)
    {
	$summary = $1;
    }
    elsif ($content =~ /\bSummary:\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$summary = $1;
    }
    elsif ($content =~ m#(?:Prompt|Summary):</b>([^<]+)#is)
    {
	$summary = $1;
    }
    elsif ($content =~ m#(?:Prompt|Summary):</strong>([^<]+)#is)
    {
	$summary = $1;
    }
    elsif ($content =~ m#(?:Prompt|Summary):</u>([^<]+)#is)
    {
	$summary = $1;
    }
    return $summary;
} # parse_summary

=head2 parse_characters

Get the characters from the content

=cut
sub parse_characters {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $characters = '';
    if ($content =~ />Characters:?\s*<\/(?:b|strong)>:?\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$characters = $1;
    }
    elsif ($content =~ /\bCharacters:\s*"?(.*?)"?\s*<br/si)
    {
	$characters = $1;
    }
    elsif ($content =~ m#<i>Characters:</i>\s*([^<]+)\s*<br>#s)
    {
	$characters = $1;
    }
    elsif ($content =~ m#(?:Pairings|Characters):</(?:b|strong|u)>([^<]+)#is)
    {
	$characters = $1;
    }
    return $characters;
} # parse_characters

=head2 parse_universe

Get the universe/fandom from the content

=cut
sub parse_universe {
    my $self = shift;
    my %args = (
	url=>'',
	content=>'',
	@_
    );

    my $content = $args{content};
    my $universe = '';
    if ($content =~ m#(?:Universe|Fandom):</(?:b|strong|u)>([^<]+)#is)
    {
	$universe = $1;
    }
    return $universe;
} # parse_universe

=head2 get_chapter

Get an individual chapter of the story, tidy it,
and save it to a file.

    $filename = $obj->get_chapter(base=>$basename,
				    count=>$count,
				    url=>$url,
				    title=>$title);

=cut

sub get_chapter {
    my $self = shift;
    my %args = (
	base=>'',
	count=>0,
	url=>'',
	title=>'',
	@_
    );

    my $content = $self->get_page($args{url});
    my ($story, $title) = $self->extract_story(%args, content=>$content);

    my $chapter_title = $self->parse_ch_title(content=>$content, url=>$args{url});
    $chapter_title = $title if !$chapter_title;

    my $html = $self->tidy(story=>$story, title=>$chapter_title);

    my %wc = $self->wordcount(content=>$story);

    #
    # Write the file
    #
    my $filename = ($args{count}
	? sprintf("%s%02d.html", $args{base}, $args{count})
	: sprintf("%s.html", $args{base}));
    my $ofh;
    open($ofh, ">",  $filename) || die "Can't write to $filename";
    print $ofh $html;
    close($ofh);

    return (
	filename=>$filename,
	title=>$chapter_title,
	wordcount=>$wc{words},
	charcount=>$wc{chars},
	);
} # get_chapter

=head2 wordcount

Figure out the word-count.

=cut
sub wordcount {
    my $self = shift;
    my %args = (
	@_
    );

    #
    # Count the words
    #
    my $stripped = $self->{stripper}->parse($args{content});
    $self->{stripper}->eof;
    $stripped =~ s/[\n\r]/ /sg; # remove line splits
    $stripped =~ s/^\s+//;
    $stripped =~ s/\s+$//;
    $stripped =~ s/\s+/ /g; # remove excess whitespace
    my @words = split(' ', $stripped);
    my $wordcount = @words;
    my $chars = length($stripped);
    return (
	words=>$wordcount,
	chars=>$chars,
    );
} # wordcount

=head2 build_toc

Build a local table-of-contents file from the meta-info about the story.

    $self->build_toc(info=>\%info);

=cut
sub build_toc {
    my $self = shift;
    my %args = (
	@_
    );
    my $info = $args{info};

    my $filename = sprintf("%s00.html", $info->{basename});

    my $html;
    $html = <<EOT;
<html>
<head><title>$info->{title}</title></head>
<body>
<h1>$info->{title}</h1>
<p>by $info->{author}</p>
<p>Fetched from <a href="$info->{url}">$info->{url}</a></p>
<p><b>Summary:</b>
$info->{summary}
</p>
<p><b>Words:</b> $info->{wordcount}<br/>
<b>Universe:</b> $info->{universe}</p>
<b>Characters:</b> $info->{characters}</p>
<ol>
EOT

    my @storyfiles = @{$info->{storyfiles}};
    my @ch_titles = @{$info->{chapter_titles}};
    my @ch_wc = @{$info->{chapter_wc}};
    for (my $i=0; $i < @storyfiles; $i++)
    {
	$html .= sprintf("<li><a href=\"%s\">%s</a> (%d)</li>",
			   $storyfiles[$i],
			   $ch_titles[$i],
			   $ch_wc[$i]);
    }
    $html .= "\n</ol>\n</body></html>\n";
    my $ofh;
    open($ofh, ">",  $filename) || die "Can't write to $filename";
    print $ofh $html;
    close($ofh);

    return $filename;
} # build_toc

=head2 build_epub

Create an EPUB file from the story files and meta information.

    $self->build_epub()

=cut
sub build_epub {
    my $self = shift;
    my %args = (
	@_
    );
    my $info = $args{info};

    my $epub = EBook::EPUB->new;
    $epub->add_title($info->{title});
    $epub->add_author($info->{author});
    $epub->add_description($info->{summary});
    $epub->add_language('en');
    $epub->add_source($info->{url}, 'URL');
    $epub->add_date($info->{fetched}, 'fetched');

    my @subjects = ();
    foreach my $key (keys %{$info})
    {
	if (!($key =~ /(?:title|author|summary|url|wordcount|basename)/)
	    and !ref $info->{$key})
	{
	    my $label = $key . ': ';
	    $label = '' if $key eq 'category';
	    if ($info->{$key} =~ /, /)
	    {
		push @subjects, map { "${label}$_" } split(/, /, $info->{$key});
	    }
	    else
	    {
		push @subjects, $label . $info->{$key};
	    }
	}
    }
    foreach my $sub (@subjects)
    {
	$epub->add_subject($sub) if $sub;
    }

    my $info_str = "<h1>$info->{title}</h1>\n";
    foreach my $key (sort keys %{$info})
    {
	next unless $info->{$key};
	if (!($key =~ /(?:basename|title)/)
	    and !ref $info->{$key})
	{
	    $info_str .= sprintf("<b>%s:</b> %s<br/>\n", $key, $info->{$key});
	}
    }

    my $titlepage = $self->tidy(story=>$info_str, title=>$info->{title});
    my $play_order = 1;
    my $id;
    $id = $epub->add_xhtml("title.html", $titlepage);

    # Add top-level nav-point
    my $navpoint = $epub->add_navpoint(
            label       => "ToC",
            id          => $id,
            content     => "title.html",
            play_order  => $play_order # should always start with 1
    );

    my @storyfiles = @{$info->{storyfiles}};
    my @ch_titles = @{$info->{chapter_titles}};
    for (my $i=0; $i < @storyfiles; $i++)
    {
	$play_order++;
	$id = $epub->copy_xhtml($storyfiles[$i], $storyfiles[$i]);
	my $navpoint = $epub->add_navpoint(
            label       => $ch_titles[$i],
            id          => $id,
            content     => $storyfiles[$i],
            play_order  => $play_order,
	);
    }

    $epub->pack_zip($info->{basename} . '.epub');

    # now unlink the storyfiles
    for (my $i=0; $i < @storyfiles; $i++)
    {
	unlink $storyfiles[$i];
    }

} # build_epub

=head2 tidy_chars

Remove nasty encodings.
    
    $content = $self->tidy_chars($content);

=cut
sub tidy_chars {
    my $self = shift;
    my $string = shift;

    # numeric entities
    $string =~ s/&#13;//sg;
    $string =~ s/&#39;/'/sg;
    $string =~ s/&#34;/"/sg;
    $string =~ s/&#45;/-/sg;
    $string =~ s/&#160;/ /sg;

    #-------------------------------------------------------
    # from Catalyst::Plugin::Params::Demoronize
    zap_cp1252($string);

    my %replace_map = (
        'â€š' => ',',     # 82, SINGLE LOW-9 QUOTATION MARK
        'â€ž' => ',,',    # 84, DOUBLE LOW-9 QUOTATION MARK
        'â€¦' => '...',   # 85, HORIZONTAL ELLIPSIS
        'Ë†' => '^',     # 88, MODIFIER LETTER CIRCUMFLEX ACCENT
        'â€˜' => '`',     # 91, LEFT SINGLE QUOTATION MARK
        'â€™' => "'",     # 92, RIGHT SINGLE QUOTATION MARK
        'â€œ' => '"',     # 93, LEFT DOUBLE QUOTATION MARK
        'â€' => '"',     # 94, RIGHT DOUBLE QUOTATION MARK
        'â€¢' => '*',     # 95, BULLET
        'â€“' => '-',     # 96, EN DASH
        'â€”' => '-',     # 97, EM DASH
        'â€¹' => '<',     # 8B, SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        'â€º' => '>',     # 9B, SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
	'âe\(tm\)' => "'",
	'âeoe' => '"',
	'âe' => '"',
	'âe~' => "'",
	'âe¦' => '...',
	'âe"' => '--',
	'\302' => '',
	'\240' => ' ',
	);

    foreach my $replace (keys(%{replace_map})) {
	my $rr = $replace_map{$replace};
	$string =~ s/$replace/$rr/g;
    }

    #-------------------------------------------------------
    # from demoronizser
    # http://www.fourmilab.ch/webtools/demoroniser/
    #-------------------------------------------------------

    #   Supply missing semicolon at end of numeric entity if
    #   Billy's bozos left it out.

    $string =~ s/(&#[0-2]\d\d)\s/$1; /g;

    #   Fix dimbulb obscure numeric rendering of &lt; &gt; &amp;

    $string =~ s/&#038;/&amp;/g;
    $string =~ s/&#060;/&lt;/g;
    $string =~ s/&#062;/&gt;/g;

    #	Translate Unicode numeric punctuation characters
    #	into ISO equivalents

    $string =~ s/&#8208;/-/sg;    	# 0x2010 Hyphen
    $string =~ s/&#8209;/-/sg;    	# 0x2011 Non-breaking hyphen
    $string =~ s/&#8211;/-/sg;   	# 0x2013 En dash
    $string =~ s/&#8212;/--/sg;   	# 0x2014 Em dash
    $string =~ s/&#8213;/--/sg;   	# 0x2015 Horizontal bar/quotation dash
    $string =~ s/&#8214;/||/sg;   	# 0x2016 Double vertical line
    $string =~ s-&#8215;-<U>_</U>-sg; # 0x2017 Double low line
    $string =~ s/&#8216;/`/sg;    	# 0x2018 Left single quotation mark
    $string =~ s/&#8217;/'/sg;    	# 0x2019 Right single quotation mark
    $string =~ s/&#8218;/,/sg;    	# 0x201A Single low-9 quotation mark
    $string =~ s/&#8219;/`/sg;    	# 0x201B Single high-reversed-9 quotation mark
    $string =~ s/&#8220;/"/sg;    	# 0x201C Left double quotation mark
    $string =~ s/&#8221;/"/sg;    	# 0x201D Right double quotation mark
    $string =~ s/&#8222;/,,/sg;    	# 0x201E Double low-9 quotation mark
    $string =~ s/&#8223;/"/sg;    	# 0x201F Double high-reversed-9 quotation mark
    $string =~ s/&#8226;/*/sg;  	# 0x2022 Bullet
    $string =~ s/&#8227;/*/sg;  	# 0x2023 Triangular bullet
    $string =~ s/&#8228;/./sg;  	# 0x2024 One dot leader
    $string =~ s/&#8229;/../sg;  	# 0x2026 Two dot leader
    $string =~ s/&#8230;/.../sg;  	# 0x2026 Horizontal ellipsis
    $string =~ s/&#8231;/&#183;/sg;  	# 0x2027 Hyphenation point
    #-------------------------------------------------------

    # and somehow some of the entities go funny
    $string =~ s/\&\#133;/.../g;
    $string =~ s/\&nbsp;/ /g;
    $string =~ s/\&lsquo;/'/g;
    $string =~ s/\&rsquo;/'/g;
    $string =~ s/\&ldquo;/"/g;
    $string =~ s/\&rdquo;/"/g;
    $string =~ s/\&ndash;/-/g;
    $string =~ s/\&hellip;/.../g;

    # replace double-breaks with <p>
    $string =~ s#<br\s*\/?>\s*<br\s*\/?>#\n<p>#sg;

    return $string;
} # tidy_chars

1; # End of WWW::FetchStory::Fetcher
__END__
