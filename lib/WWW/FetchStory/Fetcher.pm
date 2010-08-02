package WWW::FetchStory::Fetcher;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the base class for story-fetching plugins for WWW::FetchStory.

=cut

require File::Temp;
use Encode::ZapCP1252;
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

    %story_info = $obj->fetch(url=>$url);

=cut

sub fetch {
    my $self = shift;
    my %args = (
	url=>'',
	@_
    );

    $self->{verbose} = $args{verbose};

    my $toc_content = $self->get_toc($args{url});
    my %story_info = $self->parse_toc(content=>$toc_content,
				      url=>$args{url});

    warn Dump(\%story_info) if $self->{verbose};

    my @ch_urls = @{$story_info{chapters}};
    my $one_chapter = (@ch_urls == 1);
    my $first_chapter_is_toc = $story_info{toc_first};
    my $basename = $self->get_story_basename($story_info{title});
    my @storyfiles = ();
    my $count = (($one_chapter or $first_chapter_is_toc) ? 0 : 1);
    foreach (my $i = 0; $i < @ch_urls; $i++)
    {
	my $ch_title = sprintf("%s (%d)", $story_info{title}, $i+1);
	my $fn = $self->get_chapter(base=>$basename,
				    count=>$count,
				    url=>$ch_urls[$i],
				    title=>$ch_title);
	push @storyfiles, $fn;
	$count++;
    }

    $story_info{storyfiles} = \@storyfiles;

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
	if ($words[$i] !~ /^(the|a|an|of|and|to)$/)
	{
	    push @first_words, $words[$i];
	}
    }

    return join('_', @first_words);

} # get_story_basename

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

    if ($story)
    {
	$story = $self->tidy_chars($story);
    }
    else
    {
	$story = $args{content};
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
    elsif ($content =~ m#<title>([^<]+)</title>#is)
    {
	$title = $1;
    }
    return $title;
} # parse_title

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
    if ($content =~ /<(?:b|strong)>Author:\s*<\/(?:b|strong)>\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
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
    if ($content =~ /<(?:b|strong)>Summary:\s*<\/(?:b|strong)>\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
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
    if ($content =~ /<(?:b|strong)>Characters:\s*<\/(?:b|strong)>\s*"?(.*?)"?\s*<(?:br|p|\/p|div|\/div)/si)
    {
	$characters = $1;
    }
    elsif ($content =~ /\bCharacters:\s*"?(.*?)"?\s*<br/si)
    {
	$characters = $1;
    }
    elsif ($content =~ m#(?:Pairings|Characters):</b>([^<]+)#is)
    {
	$characters = $1;
    }
    elsif ($content =~ m#(?:Pairings|Characters):</strong>([^<]+)#is)
    {
	$characters = $1;
    }
    elsif ($content =~ m#(?:Pairings|Characters):</u>([^<]+)#is)
    {
	$characters = $1;
    }
    return $characters;
} # parse_characters

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

    $content = $self->tidy(content=>$content,
			   title=>$args{title});

    my $filename = ($args{count}
	? sprintf("%s%02d.html", $args{base}, $args{count})
	: sprintf("%s.html", $args{base}));
    my $ofh;
    open($ofh, ">",  $filename) || die "Can't write to $filename";
    print $ofh $content;
    close($ofh);

    return $filename;
} # get_chapter

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
    $string =~ s/&#8211;/--/sg;   	# 0x2013 En dash
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
    $string =~ s/&#8226;/&#183;/sg;  	# 0x2022 Bullet
    $string =~ s/&#8227;/&#183;/sg;  	# 0x2023 Triangular bullet
    $string =~ s/&#8228;/&#183;/sg;  	# 0x2024 One dot leader
    $string =~ s/&#8229;/../sg;  	# 0x2026 Two dot leader
    $string =~ s/&#8230;/.../sg;  	# 0x2026 Horizontal ellipsis
    $string =~ s/&#8231;/&#183;/sg;  	# 0x2027 Hyphenation point
    #-------------------------------------------------------

    # replace double-breaks with <p>
    $string =~ s#<br\s*\/?>\s*<br\s*\/?>#\n<p>#sg;
    return $string;
} # tidy_chars

1; # End of WWW::FetchStory::Fetcher
__END__
