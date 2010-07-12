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

use WWW::FetchStory::Fetcher;
use Module::Pluggable instantiate => 'new',
search_path => ['WWW::FetchStory::Fetcher'],
sub_name => 'fetchers';

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = WWW::FetchStory->new();

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    # ---------------------------------------
    # Fetchers
    # find out what fetchers are available, and group them by priority
    $self->{fetch_pri} = {};
    my @fetchers = $self->fetchers();
    foreach my $fe (@fetchers)
    {
	my $priority = $fe->priority();
	my $name = $fe->name();
	if ($self->{debug})
	{
	    print STDERR "fetcher=$name($priority)\n";
	}
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
				 verbose=>1);

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
		warn "Fetcher($pri): ", $fe->name(), "\n" if $args{verbose};
		last;
	    }
	}
	if (defined $fetcher)
	{
	    last;
	}
    }
    if (defined $fetcher)
    {
	return $fetcher->fetch(%args);
    }

} # fetch_story

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__
