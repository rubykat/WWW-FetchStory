package WWW::FetchStory::Fetcher::Teaspoon;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::Teaspoon - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the Teaspoon story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic Teaspoon fetcher, and then refinements for particular
Teaspoon community, such as the sshg_exchange community.
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

    return ($url =~ /whofic\.com/);
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
    if ($content =~ m#<u><a name="top"></a>(.*?) by ([\w\s]*)</u>#s)
    {
	$title = $1;
	$user= $2;
    }
    warn "user=$user, title=$title\n" if $self->{verbose};

    my $story = '';
    if ($content =~ m#(<strong>Summary:.*)<u>Disclaimer:</u>#s)
    {
	$story = $1;
    }
    elsif ($content =~ m#<body[^>]*>(.*)</body>#s)
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

    my $out = '';
    $out .= "<html>\n";
    $out .= "<head>\n";
    $out .= "<title>$title</title>\n";
    $out .= <<EOT;
<style type="text/css">
.title {
    font-weight: bold;
}
#notes {
border: solid black 1px;
padding: 4px;
}
</style>
EOT
    $out .= "</head>\n";
    $out .= "<body>\n";
    $out .= "<h1>$title</h1>\n";
    $out .= "<p>by $user</p>\n";
    $out .= "<p>Title: $title</p>\n";
    $out .= "<p>$story\n";
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
    my $fmt = 'http://www.whofic.com/viewstory.php?action=printable&sid=%s&textsize=0&chapter=%d';

    $info{url} = $args{url};
    my $sid='';
    if ($args{url} =~ m#sid=(\d+)#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }
    if ($content =~ m#<b>([^<]+)</b> by <a href="viewuser.php\?uid=\d+">([^<]+)</a>#s)
    {
	$info{title} = $1;
	$info{author} = $1;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
	$info{author} = $self->parse_author(%args);
    }
    # In order to get the summary and characters,
    # look at the "print" version of chapter 1
    my $ch1_url = sprintf($fmt, $sid, 1);
    my $chapter1 = $self->get_page($ch1_url);
    $info{summary} = $self->parse_summary(%args,content=>$chapter1);

    # the "Categories" here is which Doctor it is
    my $doctor = '';
    if ($chapter1 =~ m#<strong>Categories:</strong>\s*([^<]+)<br>#s)
    {
	$doctor = $1;
    }
    $info{characters} = join(", ", ($doctor, $self->parse_characters(%args,content=>$chapter1)));
    $info{universe} = 'Doctor Who';

    # fortunately Teaspoon has a sane chapter system
    if ($content =~ m#chapter=all#s)
    {
	while ($content =~ m#<a href="viewstory.php\?sid=${sid}&amp;chapter=(\d+)">#sg)
	{
	    my $ch_num = $1;
	    my $ch_url = sprintf($fmt, $sid, $ch_num);
	    warn "chapter=$ch_url\n" if $self->{verbose};
	    push @chapters, $ch_url;
	}
    }
    else
    {
	@chapters = (sprintf($fmt, $sid, 1));
    }
    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::Teaspoon
__END__
