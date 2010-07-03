
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Module::Build' => '0.3601',
    'Test::More' => '0'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Fetch a story from a fiction website',
  'dist_author' => [
    'Kathryn Andersen <perlkat@katspace.org>'
  ],
  'dist_name' => 'WWW-FetchStory',
  'dist_version' => '0.01',
  'license' => 'perl',
  'module_name' => 'WWW::FetchStory',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'File::Find::Rule' => '0',
    'File::Spec' => '0',
    'File::Temp' => '0',
    'Module::Pluggable' => '0'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
