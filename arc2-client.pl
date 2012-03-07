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

my ($configfile, $interactive, $sameas, $debug) = get_options();

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
my $missing_count = @missing_persons;
if ( $missing_count == 0 ) {
  print "ERROR! No missing persons found!\n";
  exit;
} 

if ( $interactive ) {

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
  my $missing_person = $missing_persons[$chosen_person];
  print "Name: ", $missing_person->{'name'}, "\n";
  print "URI:  ", $missing_person->{'uri'}, "\n";
  print "\n";

  # STEP 3
  # Display all known info about the chosen person

  print "Here is what we know about " . $missing_person->{'name'}, ":\n";
  my @person_info = get_info_about_uri($missing_person->{'uri'});
  foreach my $i (@person_info) {
    if ( $i->{'s'} ) { print "<", $i->{'s'}, "> "; } 
    if ( $i->{'p'} ) { print "<", $i->{'p'}, "> "; }
    if ( $i->{'o'} ) { print "<", $i->{'o'}, ">"; }
    print "\n";
  }
  print "\n";

  # FIXME
  # Make sure $missing_person is the only element in @missing_persons

}

my %waiting_uri;
my %done_uri;

foreach my $missing_person (@missing_persons) {

  # STEP 4
  # Look up data from external sources

  my $uninverted_name = uninvert($missing_person->{'name'});
  
  # Rådata nå!
  my $query = '
  PREFIX foaf: <http://xmlns.com/foaf/0.1/> 
  PREFIX owl: <http://www.w3.org/2002/07/owl#>
  SELECT DISTINCT ?s WHERE {
    { ?s foaf:name "' . $missing_person->{'name'} . '" . }
  UNION
    { ?s foaf:name "' . $uninverted_name . '" . }
  }';
  print $query if $debug;
  my $data = sparqlQuery($query, 'http://data.bibsys.no/data/authority', '', 'get');
  foreach my $t ( @{$data} ) {
    $waiting_uri{$t->{'s'}->{'value'}}++;
    print "Waiting: ", $t->{'s'}->{'value'}, "\n";
  }

  # TODO Add more sources
  # VIAF
  # Open Library
  # etc

  my $count = keys %waiting_uri;
  if ( $count == 0 ) {
    print "No sameAs found in!\n";
    next;
  }

  foreach my $uri ( keys %waiting_uri ) {
    print "$uri\n" if $debug;
    process_sameas_uri($uri, $missing_person->{'uri'});
  }

  # Empty the hashes for another go-round
  for (keys %waiting_uri) {
    delete $waiting_uri{$_};
  }
  for (keys %done_uri) {
    delete $done_uri{$_};
  }

}

sub process_sameas_uri {

  my $newuri = shift;
  my $olduri = shift;

  # TODO Let the user choose to proceed with this URI or not

  # STEP 5
  # Save the sameAs relation
  print "Saving sameAs for $newuri\n" if $debug || $sameas;
  my $query = 'INSERT INTO <' . $config->{'enh_graph'} . '> {
<' . $olduri . '> owl:sameAs <' . $newuri . '> .  
}';
  print $query if $debug || $sameas;
  my $data = sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'post');
  # TODO Check the results of this operation
  print Dumper $data if $debug;
  
  # STEP 6
  # LOAD the remote graph
  print "Loading $newuri\n" if $debug;
  my $loadquery = "LOAD <$newuri>";
  print $loadquery if $debug;
  my $loaded = sparqlQuery($loadquery, $config->{'base_url'}, $config->{'base_url_key'}, 'post');
  # TODO Check the results of this operation
  print "Loaded $loaded triples from $newuri\n";

  $done_uri{$newuri}++;

  # STEP 7
  # Get sameAs from the LOADed graph
  print "Checking for new sameAs from $newuri\n" if $debug;
  my $sameasquery = '
  SELECT ?o WHERE {
  GRAPH <' . $newuri . '> { <' . $newuri . '> owl:sameAs ?o . }
  }';
  print $sameasquery, "\n" if $debug;
  my $sameasdata = sparqlQuery($sameasquery, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  print Dumper $sameasdata if $debug;
  my $sameascount = @{$sameasdata};
  print "Found $sameascount sameAs\n" if $debug;
  foreach my $s ( @{$sameasdata} ) {
    print "Checking: ", $s->{'o'}->{'value'}, "\n" if $debug;
    if ( !exists $done_uri{$s->{'o'}->{'value'}} ) {
      print "Found ", $s->{'o'}->{'value'}, "\n" if $debug;
      process_sameas_uri( $s->{'o'}->{'value'}, $olduri );
    } else {
      print "Skipping ", $s->{'o'}->{'value'}, "\n" if $debug;
    }
  }
 
  # STEP 8
  # Display all the data we now have for the chosen person
  if ( $debug ) {
    print "Here is what we know now:\n";
    my @datawithsameas = get_data_with_sameas( $olduri );
    foreach my $i (@datawithsameas) {
      if ( $i->{'p'} ) { print "<", $i->{'p'}, "> "; }
      if ( $i->{'o'} ) { print "<", $i->{'o'}, ">"; }
      print "\n";
    }
    print "\n";
  }
  
}

# Subroutines

sub get_data_with_sameas { 

my $uri = shift;

  my $query = '
SELECT ?p ?o WHERE {
  <' . $uri . '> owl:sameAs ?id . 
  ?id ?p ?o .
}';
  my $data = sparqlQuery($query, $config->{'base_url'}, $config->{'base_url_key'}, 'get');
  my @out;
  foreach my $t ( @{$data} ) {
    my %data;
    $data{'p'} = $t->{'p'}->{'value'};
    $data{'o'} = $t->{'o'}->{'value'};
    push(@out, \%data);
  }
  return @out;

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

  if ( $sparql =~ m/^load/i ) {
    return $data->{'inserted'};
  }
  
  return $data->{'results'}->{'bindings'};
}

# Get commandline options
sub get_options {
  my $config      = '';
  my $interactive = '';
  my $sameas      = '';
  my $debug       = '';
  my $help        = '';

  GetOptions(
    'c|config=s'     => \$config, 
    'i|interactive!' => \$interactive, 
    's|sameas!'      => \$sameas,
    'd|debug!'       => \$debug,
    'h|?|help'       => \$help
  );
  
  pod2usage(-exitval => 0) if $help;

  return ($config, $interactive, $sameas, $debug);
}
