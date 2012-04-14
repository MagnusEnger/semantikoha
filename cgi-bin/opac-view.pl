#!/usr/bin/perl -w

use lib '../';

use CGI;
use LWP::UserAgent;
use URI;
use JSON;
use Template;
use Data::Dumper;
use Modern::Perl;
use Koha::SPARQL qw( get_query cgi_sparql );

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

  my $args = {
    'uri' => $uri,
  };

  # Big FIXME - This should not be hardcoded, but configurable
  # through the triplestore itself. But this a start...

  # Get all data about the URI, as a general fallback
  $query = '
    SELECT * WHERE {
    GRAPH ?g { <' . $uri . '> ?p ?o . }
  }';
  my $alldata = cgi_sparql($query);
  # warn Dumper $alldata;
  my $vars = {
    'personal'  => cgi_sparql(get_query('person.query', $args)),
    'infbydata' => cgi_sparql(get_query('influencedby.query', $args)),
    'infdata'   => cgi_sparql(get_query('influenced.query', $args)),
    'imgdata'   => cgi_sparql(get_query('images.query', $args)),
    'alldata'   => $alldata,
  };
  $tt2->process($template, $vars) || die $tt2->error();

}
