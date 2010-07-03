package WWW::FetchStory::Fetcher;
BEGIN {
  $WWW::FetchStory::Fetcher::VERSION = '0.01';
}
use strict;
use warnings;
=head1 NAME

WWW::FetchStory::Fetcher - fetching module for WWW::FetchStory

=head1 VERSION

version 0.01

=head1 SYNOPSIS

    fetch_story --use I<fetcher>

=head1 DESCRIPTION

This is the base class for story-fetching plugins for WWW::FetchStory.
Generally speaking, the only methods that backends need to override
are "new" and "fetch".

=cut

use File::Spec;

=head1 METHODS

=head2 new

There are two parameters that need to be set in "new";

=over

=item prog

The name of the program which is used as the fetcher.

=item can_do

A hash containing the features that the fetcher provides.

=back

=cut

sub new {
    my $class = shift;
    my %parameters = @_;
    my $self = bless ({%parameters}, ref ($class) || $class);
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

=head2 active

Returns true if the fetcher program is available to run.
This is checked by searching the PATH environment variable and checking
for the existence of $self->{prog}

=cut

sub active {
    my $self = shift;

    my @path = split(':', $ENV{PATH});
    my $found = 0;
    foreach my $dir (@path)
    {
	my $file = File::Spec->catfile($dir, $self->{prog});
	if (-f $file)
	{
	    $found = 1;
	    last;
	}
    }
    return $found;
} # active

=head2 provides

Returns a hash of the features the fetcher has enabled.

=cut

sub provides {
    my $self = shift;

    my %prov = ();
    if (defined $self->{can_do})
    {
	%prov = %{$self->{can_do}};
    }
    return %prov;
} # provides

=head2 fetch

Fetch the story, with the given options.
This must be overridden by the specific fetcher class.

=cut

sub fetch {
    my $self = shift;

    return 0;
} # fetch

1; # End of WWW::FetchStory::Fetcher
__END__