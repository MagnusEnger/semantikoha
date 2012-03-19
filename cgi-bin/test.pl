#!/usr/bin/perl -w

use lib '../';

use CGI;
use LWP::UserAgent;
use URI;
use JSON;
use Template;
use Data::Dumper;
use Modern::Perl;
use Koha::LinkedData;

my $q = CGI->new;

# Configure Template Toolkit
my $config = {
    INCLUDE_PATH => '../templates/', # or list ref
    POST_CHOMP => 1, # cleanup whitespace
    ENCODING => 'utf8' # ensure correct encoding
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";
my $template = 'default.tt';
my $query = '';

print "Content-type: text/html\n\n";

if ( $q->param('id') ) {

  $template  = 'rec_insert.tt';
  my $fullid = $q->param('id');
  my ($dummy1, $dummy2, $id) = split ':', $fullid;

  $query = 'PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dbpo: <http://dbpedia.org/ontology/>
SELECT DISTINCT ?uri ?name ?thumb WHERE {
  {
  <http://esme.priv.bibkat.no/records/id_' . $id . '> dcterms:creator ?uri .
  ?uri foaf:name ?name .
  OPTIONAL {
    ?uri owl:sameAs ?x . 
    ?x dbpo:thumbnail ?thumb 
  }
} UNION {
  <http://esme.priv.bibkat.no/records/id_' . $id . '> dcterms:contributor ?uri .
  ?uri foaf:name ?name .
  OPTIONAL {
    ?uri owl:sameAs ?x . 
    ?x dbpo:thumbnail ?thumb 
  }
  }
}';

  my $data = Koha::LinkedData::cgi_sparql($query);
  my $vars = {
    'rec_id' => $id,
    'data'   => $data,
  };
  $tt2->process($template, $vars) || die $tt2->error();

} elsif ( $q->param('uri') ) {

  my $uri = $q->param('uri');

  my $imgquery = '
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?img WHERE {
<' . $uri . '> owl:sameAs ?o . 
?o foaf:depiction ?img
}';
  my $imgdata = Koha::LinkedData::cgi_sparql($imgquery);

  # Get all data about the URI, as a general fallback
  $query = '
    SELECT * WHERE {
    GRAPH ?g { <' . $uri . '> ?p ?o . }
  }';
  my $alldata = Koha::LinkedData::cgi_sparql($query);
  warn Dumper $alldata;
  my $vars = {
    'imgdata' => $imgdata,
    'alldata' => $alldata,
  };
  $tt2->process($template, $vars) || die $tt2->error();

}

# Get foaf:name where it exists
# PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# SELECT * WHERE {
#     <http://esme.priv.bibkat.no/records/id_2> ?p ?o . 
#     OPTIONAL { ?o foaf:name ?name } .
# }

