package WWW::FetchStory::Fetcher::HPAdultFanfiction;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::HPAdultFanfiction - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the HPAdultFanfiction story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head1 METHODS

=head2 new

$obj->WWW::FetchStory::Fetcher->new();

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    # disable the User-Agent for HPAdultFanfiction
    # because it blocks wget
    $self->{wget} .= " --user-agent=''";

    return ($self);
} # new

=head2 info

Information about the fetcher.

$info = $self->info();

=cut

sub info {
    my $self = shift;
    
    my $info = "(http://hp.adultfanfiction.net) An adult Harry Potter fiction archive.";

    return $info;
} # info

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic HPAdultFanfiction fetcher, and then refinements for particular
HPAdultFanfiction community, such as the sshg_exchange community.
This works as either a class function or a method.

This must be overridden by the specific fetcher class.

$priority = $self->priority();

$priority = WWW::FetchStory::Fetcher::priority($class);

=cut

sub priority {
    my $class = shift;

    return 2;
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

    return ($url =~ /hp\.adultfanfiction\.net/);
} # allow

=head1 Private Methods

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
    if ($args{url} =~ m#no=(\d+)#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }
    $info{title} = $self->parse_title(%args);
    $info{author} = $self->parse_author(%args);
    $info{summary} = $self->parse_summary(%args);
    $info{characters} = $self->parse_characters(%args);
    $info{universe} = 'Harry Potter';
    $info{rating} = 'Adult';

    my $fmt = 'http://hp.adultfanfiction.net/story.php?no=%d&chapter=%d';
    my $max_chapter = 0;
    while ($content =~ m#<option value='story\.php\?no=${sid}&chapter=(\d+)'#gs)
    {
	my $a_ch = $1;
	if ($a_ch > $max_chapter)
	{
	    $max_chapter = $a_ch;
	}
    }
    for (my $ch = 1; $ch <= $max_chapter; $ch++)
    {
	my $ch_url = sprintf($fmt, $sid, $ch);
	warn "chapter=$ch_url\n" if $self->{verbose};
	push @chapters, $ch_url;
    }

    $info{chapters} = \@chapters;
    warn "This interface is incomplete.\n";

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
    if ($content =~ m#<title>\s*Story:\s*([^<]+)\s*</title>#is)
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
    if ($content =~ m/Author:\s*<a href='authors\.php\?no=\d+'>\s*([^<]+)\s*<\/a>/s)
    {
	$author = $1;
    }
    else
    {
	$author = $self->SUPER::parse_author(%args);
    }
    return $author;
} # parse_author

1; # End of WWW::FetchStory::Fetcher::HPAdultFanfiction
__END__
