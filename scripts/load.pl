#!/usr/bin/perl -w 

# LOAD the URI given as the first argument on the command line
# Synopsis: load.pl <uri>

# TODO Turn this into a function

use Data::Dumper;
use YAML::Syck qw'LoadFile';
use Modern::Perl;
use diagnostics;
use Koha::LinkedData;

# Read the YAML file
my ($config) = LoadFile('config/config.yaml');

my $newuri = '';

if ($ARGV[0]) {
  $newuri = $ARGV[0];
} else {
  die "No URI given\n";
}

print "Loading $newuri\n";
my $loadquery = "LOAD <$newuri>";
my $loaded = Koha::LinkedData::sparqlQuery($loadquery, $config->{'base_url'}, $config->{'base_url_key'}, 'post');
print "Loaded $loaded triples from $newuri\n";
