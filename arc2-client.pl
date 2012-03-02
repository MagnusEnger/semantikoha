#!/usr/bin/perl -w 

# This script is a proof-of-concept that aims to uncover:
# - A workflow for enhancing data converted from bibliographic records to RDF 
#   and stored in a triplestore with data from other source
# - The SPARQL-queries involved in that process

use CGI qw/:standard/;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;
use YAML::Syck qw'LoadFile';
use Getopt::Long;
use Pod::Usage;
use Modern::Perl;
use diagnostics;

my ($configfile, $debug) = get_options();

# Check that the YAML config file actually exists
if ( $configfile ne '' && !-e $configfile) {
  die "Couldn't find YAML file $configfile\n";
}
if ( -e 'config.yaml' ) {
  # Use the default config file if one is not given on the command line
  $configfile = 'config.yaml';
}
print "YAML: $configfile\n" if $debug;

# Read the YAML file
my ($config) = LoadFile($configfile);

# STEP 1
# Get all the persons that have not been enhanced with external data

my @missing_persons = get_person_without_sameas(3);

# STEP 2
# Let the user choose one person to focus on

print join( "\n", @missing_persons ), "\n";

# STEP 3
# Display all known info about the chosen person

# STEP 4
# Look up data from external sources
# Rådata nå!
# VIAF
# Open Library

# STEP 5
# Let the user choose which relations/data to import

# STEP 6
# Update the triplestore with the chosen data

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

  my $data = sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  my @out;
  foreach my $p ( @{$data} ) {
    push(@out, $p->{'s'}->{'value'});
  }
  return @out;
}

sub show_data {
  my $query = shift;
  my $data=sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  print Dumper($data);
}

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
  my $config = '';
  my $debug  = '';
  my $help   = '';

  GetOptions(
    'c|config=s' => \$config, 
    'd|debug!'   => \$debug,
    'h|?|help'   => \$help
  );
  
  pod2usage(-exitval => 0) if $help;

  return ($config, $debug);
}
