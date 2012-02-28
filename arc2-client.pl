#!/usr/bin/perl -w 

use CGI qw/:standard/;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;
use Getopt::Long;
use Pod::Usage;
use Modern::Perl;
use diagnostics;

my $base_url = 'http://data.libriotech.no/semantikoha/';
my $key      = 'password';

my ($debug) = get_options();

my @missing_persons = get_person_without_sameas(3);
print join( "\n", @missing_persons ), "\n";

# show_data('SELECT * WHERE { <http://esme.priv.bibkat.no/records/id_2> ?p ?o . }');

# foreach my $d ( @{ $data } ) {
#   my $uri = $d->{'o'}->{'value'};
#   my $query="LOAD <$uri>";
#   my $data=sparqlQuery($query, $base_url, 'post');
#   print Dumper($data) if $debug;
# }

# Subroutines

sub get_person_without_sameas {

  my $limit = 10;
  $limit = shift;

  my $query = '
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?s WHERE {
  ?s a foaf:Person .
  OPTIONAL { ?s owl:sameAs ?id . }
  FILTER(!bound(?id))
} 
LIMIT ' . $limit;

  my $data = sparqlQuery($query, $base_url, 'get');
  my @out;
  foreach my $p ( @{$data} ) {
    push(@out, $p->{'s'}->{'value'});
  }
  return @out;
}

sub show_data {
  my $query = shift;
  my $data=sparqlQuery($query, $base_url, 'get');
  print Dumper($data);
}

sub sparqlQuery {
  my $sparql  = shift;
  my $baseURL = shift;
  my $method  = shift;

  my %params=(
    'query'  => $sparql,
    'output' => 'json',
    'key'    => $key,
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
    print $res->decoded_content if $debug;
  } else {
    print $res->status_line, "\n";
  }
  
  my $str = $res->content;

  print Dumper $str if $debug;
  
  my $data = decode_json($str);
  
  return $data->{'results'}->{'bindings'};
}

# Get commandline options
sub get_options {
  my $debug = '';
  my $help  = '';

  GetOptions(
    'd|debug!' => \$debug,
    'h|?|help' => \$help
  );
  
  pod2usage(-exitval => 0) if $help;

  return ($debug);
}
