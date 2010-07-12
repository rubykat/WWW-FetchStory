use strict;
use warnings;
package WWW::FetchStory;
=head1 NAME

WWW::FetchStory - Fetch a story from a fiction website

=head1 SYNOPSIS

    use WWW::FetchStory;

    my $obj = WWW::FetchStory->new(%args);

    my %story_info = $obj->fetch_story(url=>$url);

=head1 DESCRIPTION

This will fetch a story from a fiction website, intelligently
dealing with the formats from various different fiction websites
such as fanfiction.net; it deals with multi-file stories,
and strips all the extras from the HTML (such as navbars and javascript)
so that all you get is the story text and its formatting.

=cut

require File::Temp;
use LWP::UserAgent;
use HTTP::Cookies::Netscape;

use WWW::FetchStory::Fetcher;
use Module::Pluggable instantiate => 'new', search_path => 'WWW::FetchStory::Fetcher', sub_name => 'fetchers';

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = WWW::FetchStory->new(
	config_dir=>"$ENV{HOME}/.fetch_story",
	);

=cut

sub new {
    my $class = shift;
    my %parameters = (
	config_dir => "$ENV{HOME}/.fetch_story",
	@_
    );
    my $self = bless ({%parameters}, ref ($class) || $class);

    # ---------------------------------------
    # User Agent
    # We only need one user-agent, so share it amongst all the fetchers

    $self->{user_agent} = LWP::UserAgent->new;
    $self->{user_agent}->env_proxy; # proxy from environment variables

    # be prepared for cookies
    my $cookie_fh = File::Temp->new(TEMPLATE => 'fcookXXXXX');
    my $cookie_file = $cookie_fh->filename;
    my $cookie_jar = HTTP::Cookies::Netscape->new(file => $cookie_file,
						  autosave => 0);
    if (-f "$ENV{HOME}/cookies.txt")
    {
	$cookie_jar->load("$ENV{HOME}/cookies.txt");
    }
    $self->{user_agent}->cookie_jar($cookie_jar);

    # ---------------------------------------
    # Fetchers
    # find out what fetchers are available, and group them by priority

    $self->{fetch_pri} = {};
    my @fetchers = $self->fetchers(user_agent=>$self->{user_agent});
    foreach my $fe (@fetchers)
    {
	my $priority = WWW::FetchStory::Fetcher::priority($fe);
	if (!exists $self->{fetch_pri}->{$priority})
	{
	    $self->{fetch_pri}->{$priority} = [];
	}
	push @{$self->{fetch_pri}->{$priority}}, $fe;
    }

    return ($self);
} # new

=head2 fetch_story

    my %story_info = fetch_story(
	url=>$url,
	basename=>$basename);

=cut
sub fetch_story ($%) {
    my $self = shift;
    my %args = (
	url=>'',
	verbose=>0,
	@_
    );

    my $fetcher;
    foreach my $pri (reverse sort keys %{$self->{fetch_pri}})
    {
	foreach my $fe (@{$self->{fetch_pri}->{$pri}})
	{
	    if ($fe->allow($args{url}))
	    {
		$fetcher = $fe;
	    }
	}
    }
    if (defined $fetcher)
    {
	return $fetcher->fetch(url=>$args{url});
    }

} # fetch_story

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__
