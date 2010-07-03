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

    use WWW::FetchStory qw(:all);

    my %story_info = fetch_story(
	url=>$url,
	basename=>$basename);

=head1 DESCRIPTION

This will fetch a story from a fiction website, intelligently
dealing with the formats from various different fiction websites
such as fanfiction.net; it deals with multi-file stories,
and strips all the extras from the HTML (such as navbars and javascript)
so that all you get is the story text and its formatting.

=cut

use HTML::SimpleParse;
use File::Temp qw(tempdir);
use File::Find::Rule;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration
# use Text::ParseStory ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
    'all' => [
        qw(
        get_story_info
        )
    ]
);

our @EXPORT_OK = (@{$EXPORT_TAGS{'all'}});

our @EXPORT = qw(

);

=head1 FUNCTIONS

=head2 fetch_story

    my %story_info = fetch_story(
	url=>$url,
	basename=>$basename);

=cut
sub fetch_story (%) {
    my %args = (
	file=>'',
	columns=>undef,
	url=>'',
	verbose=>0,
	@_
    );

    my %story_info = ();
    foreach my $col (@{$args{columns}})
    {
	$story_info{$col} = '';
    }
    if ($args{file} =~ /.txt$/)
    {
	extract_info_from_text(vals=>\%story_info, %args);
    }
    elsif ($args{file} =~ /.zip$/)
    {
	extract_info_from_zip(vals=>\%story_info, %args);
    }
    else
    {
	extract_info_from_html(vals=>\%story_info, %args);
    }
    return %story_info;
} # fetch_story

=head1 Private Functions

=head2 fetch_from_ffn

Fetch a story from fanfiction.net.

=cut
sub fetch_from_ffn (%) {
    my %args = (
		url=>'',
		basename=>undef,
		@_
	       );

} # fetch_from_ffn

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__