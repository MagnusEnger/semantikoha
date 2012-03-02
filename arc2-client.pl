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

my @missing_persons = get_person_without_sameas();

# STEP 2
# Let the user choose one person to focus on

my $person_count = 0;
foreach my $p ( @missing_persons ) {
  print $person_count, " ", $p->{'name'}, "\t", $p->{'uri'}, "\n";
  $person_count++;
}
print "\n";

print "Choose a person (number from the list above): ";
my $chosen_person = <>;
print "You chose person number $chosen_person";
my $uninverted_name = uninvert($missing_persons[$chosen_person]->{'name'});
print "Name: ", $missing_persons[$chosen_person]->{'name'}, " / $uninverted_name\n";
print "URI:  ", $missing_persons[$chosen_person]->{'uri'}, "\n";
print "\n";

# STEP 3
# Display all known info about the chosen person

print "Here is what we know about " . $missing_persons[$chosen_person]->{'name'}, ":\n";
my @person_info = get_info_about_uri($missing_persons[$chosen_person]->{'uri'});
foreach my $i (@person_info) {
  if ( $i->{'s'} ) { print "<", $i->{'s'}, "> "; } 
  if ( $i->{'p'} ) { print "<", $i->{'p'}, "> "; }
  if ( $i->{'o'} ) { print "<", $i->{'o'}, ">"; }
  print "\n";
}
print "\n";

# STEP 4
# Look up data from external sources
  
my $sameasdata = get_sameas_for_person($missing_persons[$chosen_person]->{'name'}, $uninverted_name);

# STEP 5
# Let the user choose which relations/data to import
# TODO The actual choosing...

foreach my $sameasuri ( keys %{ $sameasdata } ) {
  print "$sameasuri\n";
}
print "\n";

# STEP 6
# Update the triplestore with the chosen data

foreach my $sameasuri ( keys %{ $sameasdata } ) {
  print "$sameasuri\n";
  save_sameas_data($sameasuri, $missing_persons[$chosen_person]->{'uri'});
}
print "\n";

# Subroutines

sub save_sameas_data {

  my $newuri = shift;
  my $olduri = shift;
  
  # Save the sameAs relation
  my $query = 'INSERT INTO <' . $config->{'enh_graph'} . '> {
<' . $olduri . '> owl:sameAs <' . $newuri . '> .  
}';
  print $query if $debug;
  my $data=sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'post');
  print Dumper($data) if $debug;
  
  # LOAD the remote graph
  my $loadquery = "LOAD <$newuri>";
  print $loadquery if $debug;
  my $loaddata=sparqlQuery($loadquery, $config->{'base_url'}, $config->{'base_url_key'}, 'post');
  print Dumper($loaddata) if $debug;

}

sub get_sameas_for_person {

  my $name1 = shift;
  my $name2 = shift;
  
  # Rådata nå!
  my $query = '
PREFIX foaf: <http://xmlns.com/foaf/0.1/> 
PREFIX owl: <http://www.w3.org/2002/07/owl#>
SELECT * WHERE {
  { ?s foaf:name "' . $name1 . '" .
  ?s owl:sameAs ?o . }
  UNION
  { ?s foaf:name "' . $name2 . '" .
  ?s owl:sameAs ?o . }
}';
  print $query if $debug;
  my $data = sparqlQuery($query, 'http://data.bibsys.no/data/authority', '', 'get');
  my %out;
  foreach my $t ( @{$data} ) {
    $out{$t->{'s'}->{'value'}}++;
    $out{$t->{'o'}->{'value'}}++;
  }

  # TODO VIAF
  # TODO Open Library

  return \%out;

}

sub uninvert {
  my $orig = shift;
  if ( $orig =~ m/,/ ) {
    my ($first, $second) = split ', ', $orig;
    return "$second $first";
  } else {
    return $orig;
  }
}

sub get_info_about_uri {
 
  my $uri = shift;

  my $query = '
SELECT * { 
  { <' . $uri . '> ?p ?o } 
  UNION 
  { ?s ?p <' . $uri . '> } 
}';
  my $data = sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  my @out;
  foreach my $t ( @{$data} ) {
    my %triple;
    $triple{'s'} = $t->{'s'}->{'value'};
    $triple{'p'} = $t->{'p'}->{'value'};
    $triple{'o'} = $t->{'o'}->{'value'};
    push(@out, \%triple);
  }
  return @out;
}

sub get_person_without_sameas {

  my $query = '
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?uri ?name WHERE {
  GRAPH <' . $config->{'default_graph'} . '> {
    ?uri a foaf:Person .
    OPTIONAL { ?uri foaf:name ?name . }
    OPTIONAL { ?uri owl:sameAs ?id . }
    FILTER(!bound(?id))
  }
}
LIMIT ' . $config->{'person_without_sameas_limit'};

  my $data = sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  my @out;
  foreach my $p ( @{$data} ) {
    my %person;
    $person{'uri'} = $p->{'uri'}->{'value'};
    $person{'name'} = $p->{'name'}->{'value'};
    push(@out, \%person);
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
