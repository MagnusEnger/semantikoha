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
  my %ttvars;

  # Get the main template
  my $tpl = cgi_sparql(get_query('type_to_template.query', $args));
  if ($tpl && $tpl->[0]) {
    $template = $tpl->[0]->{'template'}->{'value'} . '.tt';
  }

  # Get all the queries for the types of the URI we are dealing with
  # and execute them, saving the results in %ttvars
  my $queries = cgi_sparql(get_query('type_to_queries.query', $args));
  foreach my $query ( @{$queries} ) {
    # print get_query( $query->{'query'}->{'value'} . '.query', $args );
    $ttvars{ $query->{'query'}->{'value'} } = cgi_sparql( get_query( $query->{'query'}->{'value'} . '.query', $args ) );
  }

  # Get all data about the URI, as a general fallback
  # FIXME Create a tmeplate for this
  my $allquery = '
    SELECT * WHERE {
    GRAPH ?g { <' . $uri . '> ?p ?o . }
  }';
  $ttvars{'alldata'} = cgi_sparql($allquery);

  # Debug
  # print Dumper %ttvars;

  $tt2->process($template, \%ttvars) || die $tt2->error();

}
