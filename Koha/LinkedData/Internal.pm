package Koha::LinkedData::Internal;

use Koha::LinkedData;
use YAML::Syck;
use Modern::Perl;

# Read the YAML file
my ($config) = LoadFile('./config/config.yaml');

sub load {

  my $uri = shift;
  
  # TODO Check that $uri is a valid URI

  my $loadquery = "LOAD <$uri>";
  Koha::LinkedData::sparqlQuery($loadquery, $config->{'base_url'}, $config->{'base_url_key'}, 'post');

}

1;
