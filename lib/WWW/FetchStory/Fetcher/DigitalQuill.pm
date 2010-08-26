package WWW::FetchStory::Fetcher::DigitalQuill;
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher::DigitalQuill - fetching module for WWW::FetchStory

=head1 DESCRIPTION

This is the DigitalQuill story-fetching plugin for WWW::FetchStory.

=cut

our @ISA = qw(WWW::FetchStory::Fetcher);

=head2 priority

The priority of this fetcher.  Fetchers with higher priority
get tried first.  This is useful where there may be a generic
fetcher for a particular site, and then a more specialized fetcher
for particular sections of a site.  For example, there may be a
generic DigitalQuill fetcher, and then refinements for particular
DigitalQuill community, such as the sshg_exchange community.
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
    if ($args{url} =~ m#sid=(\d+)#)
    {
	$sid = $1;
    }
    else
    {
	return $self->SUPER::parse_toc(%args);
    }

    if ($content =~ m#<h4>\s*([^<]+)</h4>#)
    {
	$info{title} = $1;
    }
    else
    {
	$info{title} = $self->parse_title(%args);
    }

    if ($content =~ m#by <a href="viewuser.php\?uid=\d+">([^<]+)</a>#s)
    {
	$info{author} = $1;
    }
    else
    {
	$info{author} = $self->parse_author(%args);
    }

    if ($content =~ m#<i>Summary:</i>\s*([^<]+)\s*<br>#s)
    {
	$info{summary} = $1;
    }
    if ($content =~ m#<i>Characters:</i>\s*([^<]+)\s*<br>#s)
    {
	$info{characters} = $1;
    }
    $info{universe} = 'Harry Potter';

    # DigitalQuill does not have a sane chapter system
    my $fmt = 'http://www.digital-quill.org/viewstory.php?action=printable&sid=%d';
    while ($content =~ m#viewstory.php\?sid=(\d+)#sg)
    {
	my $ch_sid = $1;
	my $ch_url = sprintf($fmt, $ch_sid);
	warn "chapter=$ch_url\n" if $self->{verbose};
	push @chapters, $ch_url;
    }
    $info{chapters} = \@chapters;

    return %info;
} # parse_toc

1; # End of WWW::FetchStory::Fetcher::DigitalQuill
__END__
