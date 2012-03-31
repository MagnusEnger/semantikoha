#!/usr/bin/perl -w 

# Find language URIs that have not been LOADed and LOAD them
# Synopsis: language.pl 

use lib '../';

use Koha::LinkedData::Internal;
use Modern::Perl;
use Data::Dumper;

my $query = '
SELECT DISTINCT ?lang ?label WHERE {
  ?s <http://purl.org/dc/terms/language> ?lang . 
  OPTIONAL { ?lang rdfs:label ?label . }
  FILTER (!bound(?label))
}';

my $langs = Koha::LinkedData::get_sparql($query);

foreach my $lang ( @{$langs} ) {

  if ($lang->{'lang'}->{'type'} && $lang->{'lang'}->{'type'} eq 'uri') {
    Koha::LinkedData::Internal::verbose_load($lang->{'lang'}->{'value'});
  }

}
