#!/usr/bin/perl -w

use lib '../';

use CGI;
use LWP::UserAgent;
use URI;
use JSON;
use Template;
use Data::Dumper;
use Modern::Perl;
use Koha::SPARQL qw( cgi_sparql );

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

  my $data = cgi_sparql($query);
  my $vars = {
    'rec_id' => $id,
    'data'   => $data,
  };
  $tt2->process($template, $vars) || die $tt2->error();

} elsif ( $q->param('uri') ) {

  my $uri = $q->param('uri');

  # Images
  my $imgquery = '
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?img WHERE {
    <' . $uri . '> owl:sameAs ?o . 
    ?o foaf:depiction ?img
  }';
  my $imgdata = cgi_sparql($imgquery);

  # Big FIXME - This should not be hardcoded, but configurable
  # through the triplestore itself. But this a start...

  #Personal information
  my $personalquery = '
  PREFIX dbp: <http://dbpedia.org/property/>
  SELECT * WHERE {
    <' . $uri . '> dbp:name ?name . 
    OPTIONAL { <' . $uri . '> dbp:birthDate ?birthdate }
    OPTIONAL { <' . $uri . '> dbp:deathDate ?deathdate }
    FILTER (!(regex(?name, ",")))
  }';
  my $personaldata = cgi_sparql($personalquery);
  
  # Inluenced by
  my $infbyquery = '
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT DISTINCT ?influencedby ?name WHERE {
    <' . $uri . '> <http://www.w3.org/2002/07/owl#sameAs> ?sameAs .
    ?sameAs <http://dbpedia.org/ontology/influencedBy> ?influencedby
    OPTIONAL { ?influencedby <http://xmlns.com/foaf/0.1/name> ?name . }
  }';
  my $infbydata = cgi_sparql($infbyquery);

  # Inluenced
  my $infquery = '
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT DISTINCT ?influenced ?name WHERE {
    <' . $uri . '> <http://www.w3.org/2002/07/owl#sameAs> ?sameAs .
    ?sameAs <http://dbpedia.org/property/influenced> ?influenced .
    OPTIONAL { ?influenced <http://xmlns.com/foaf/0.1/name> ?name . }
  }';
  my $infdata = cgi_sparql($infquery);

  # Get all data about the URI, as a general fallback
  $query = '
    SELECT * WHERE {
    GRAPH ?g { <' . $uri . '> ?p ?o . }
  }';
  my $alldata = cgi_sparql($query);
  warn Dumper $alldata;
  my $vars = {
    'personal'  => $personaldata,
    'infbydata' => $infbydata,
    'infdata'   => $infdata,
    'imgdata'   => $imgdata,
    'alldata'   => $alldata,
  };
  $tt2->process($template, $vars) || die $tt2->error();

}

# Get foaf:name where it exists
# PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# SELECT * WHERE {
#     <http://esme.priv.bibkat.no/records/id_2> ?p ?o . 
#     OPTIONAL { ?o foaf:name ?name } .
# }

