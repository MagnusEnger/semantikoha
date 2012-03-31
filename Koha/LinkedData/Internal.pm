package Koha::LinkedData::Internal;

use Koha::LinkedData;
use YAML::Syck;
use Modern::Perl;

# Read the YAML file
my ($config) = LoadFile('../config/config.yaml');

# Load a URI into our own triplestore
# Usage:
# load(uri)

sub load {

  my ($uri) = @_;
  
  # TODO Check that $uri is a valid URI

  my $loadquery = "LOAD <$uri>";
  Koha::LinkedData::sparqlQuery($loadquery, 'post');

}

1;
