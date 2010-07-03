use strict;
use warnings;
package WWW::FetchStory;
BEGIN {
  $WWW::FetchStory::VERSION = '0.01';
}
=head1 NAME

WWW::FetchStory - Fetch a story from a fiction website

=head1 VERSION

version 0.01

=head1 SYNOPSIS

    use WWW::FetchStory;

    my $obj = WWW::FetchStory->new(%args);

    my %story_info = $obj->fetch_story(
	url=>$url,
	basename=>$basename);

=head1 DESCRIPTION

This will fetch a story from a fiction website, intelligently
dealing with the formats from various different fiction websites
such as fanfiction.net; it deals with multi-file stories,
and strips all the extras from the HTML (such as navbars and javascript)
so that all you get is the story text and its formatting.

=cut

use File::Temp qw(tempdir);
use File::Find::Rule;
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
    return ($self);
} # new

=head2 fetch_story

    my %story_info = fetch_story(
	url=>$url,
	basename=>$basename);

=cut
sub fetch_story (%) {
    my %args = (
	url=>'',
	verbose=>0,
	@_
    );

} # fetch_story

=head1 Private Functions

=head2 get_fetchers

    my @fetchers = $obj->get_fetchers();

Return which fetchers are available.

=cut
sub get_fetchers($) {
    my $self = shift;

    my @avail_fetchers = ();
    my @fetchers = $self->fetchers();
    foreach my $be (@fetchers)
    {
	if ($be->active())
	{
	    push @avail_fetchers, WWW::FetchStory::Fetcher::name($be);
	}
    }
    return @avail_fetchers;
} # get_fetchers

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__