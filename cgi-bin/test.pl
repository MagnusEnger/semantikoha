#!/usr/bin/perl -w

use CGI;
use LWP::UserAgent;
use URI;
use JSON;
use Template;
use Data::Dumper;
use Modern::Perl;

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

} elsif ( $q->param('uri') ) {

  my $uri = $q->param('uri');
  $query = '
SELECT * WHERE {
  GRAPH ?g { <' . $uri . '> ?p ?o . }
}';

}

# print "$query\n";

my $data = sparqlQuery($query, 'http://data.libriotech.no/semantikoha/', '', 'get');

my $vars = {
  'data' => $data,
};
$tt2->process($template, $vars) || die $tt2->error();

# Get foaf:name where it exists
# PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# SELECT * WHERE {
#     <http://esme.priv.bibkat.no/records/id_2> ?p ?o . 
#     OPTIONAL { ?o foaf:name ?name } .
# }

# Subroutines

sub sparqlQuery {
  my $sparql     = shift;
  my $baseURL    = shift;
  my $baseURLkey = shift;
  my $method     = shift;

  my %params=(
    'query'  => $sparql,
    'output' => 'json',
    'key'    => $baseURLkey,
  );

  my $ua = LWP::UserAgent->new;
  $ua->agent("semantikoha");
  my $res = '';
  if ($method eq 'get') {
    my $url = URI->new($baseURL);
    $url->query_form(%params);
    $res = $ua->get($url);
  } elsif ($method eq 'post') {
    $res = $ua->post($baseURL, Content => \%params);
  }
  
  if ($res->is_success) {
    # print $res->decoded_content;
  } else {
    print $res->status_line, "\n";
  }
  
  my $str = $res->content;

  my $data = decode_json($str);
  
  return $data->{'results'}->{'bindings'};
}
