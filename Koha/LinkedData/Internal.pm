package Koha::LinkedData::Internal;

use Koha::LinkedData;
use YAML::Syck;
use Modern::Perl;

# Read the YAML file
my ($config) = LoadFile('../config/config.yaml');

# Load a URI into our own triplestore
# Usage:
# load(uri)

sub sparql_insert {

  my ($q) = @_;
  return Koha::LinkedData::sparqlQuery($q, 'post');

}

sub verbose_load {

  my ($newuri) = @_;

  print "Loading $newuri\n";
  my $loaded = Koha::LinkedData::Internal::load($newuri);
  print "Loaded $loaded triples from $newuri\n";

}

sub load {

  my ($uri) = @_;
  
  # TODO Check that $uri is a valid URI

  my $loadquery = "LOAD <$uri>";
  Koha::LinkedData::sparqlQuery($loadquery, 'post');

}

1;
