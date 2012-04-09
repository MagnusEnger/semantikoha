package Koha::SPARQL;

# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use CGI qw/:standard/;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;
use YAML::Syck;
use Template;
use Modern::Perl;
use diagnostics;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( 
  get_sparql 
  get_query 
); 
our @EXPORT_OK = qw( 
  sparql_external
  load 
  verbose_load 
  sparql_insert
); 
our %EXPORT_TAGS = ( 
  update => [ qw( 
    load 
    verbose_load 
    sparql_insert 
  ) ],
);

# Read the default YAML file
my ($config) = LoadFile('../config/config.yaml');

# Configure Template Toolkit
my $ttconfig = {
  INCLUDE_PATH => '../templates/', # or list ref
  POST_CHOMP => 1, # cleanup whitespace
  ENCODING => 'utf8', # ensure correct encoding
  RELATIVE => 1,
};
# Create Template object
my $tt2 = Template->new($ttconfig) || die Template->error(), "\n";

sub get_query {

  my ($template, $args) = @_;
  my ( $query );
  my $vars = {
    'args'   => $args,
    'config' => $config,
  };
  $tt2->process( $template, $vars, \$query ) || die $tt2->error();
  return $query;

}

sub get_sparql {

  my ( $sparql_query ) = @_;
  return _sparql_query( $sparql_query, 'get' );

}

sub sparql_external {

  my ( $sparql_query, $baseurl ) = @_;
  return _sparql_query( $sparql_query, 'get', $baseurl );

}

sub cgi_sparql {

  my ( $sparql_query ) = shift;
  return _sparql_query( $sparql_query, 'get' );

}

# Load a URI into our own triplestore
# Usage:
# load(uri)

sub sparql_insert {

  my ( $sparql_query ) = @_;
  return _sparql_query( $sparql_query, 'post' );

}

sub verbose_load {

  my ( $newuri ) = @_;

  print "Loading $newuri\n";
  my $loaded = load( $newuri );
  print "Loaded $loaded triples from $newuri\n";

}

sub load {

  my ( $uri ) = @_;
  
  # TODO Check that $uri is a valid URI

  my $loadquery = "LOAD <$uri>";
  _sparql_query( $loadquery, 'post' );

}

sub _sparql_query {
  
  my ($sparql, $method, $baseURL, $baseURLkey, $debug) = @_;
  
  if ( !$baseURL ) {
    # Use the default baseURL
    $baseURL = $config->{'base_url'};
    if ( !$baseURLkey ) {
      # Only set baseURLkey to the default if we are going to talk
      # to our own baseURL, otherwise we will be sending our password
      # to remote baseURls!
      $baseURLkey = $config->{'base_url_key'};
    }
  } 
  
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

  if ( $sparql =~ m/^load/i || $sparql =~ m/^insert/i ) {
    return $data->{'inserted'};
  }
  
  return $data->{'results'}->{'bindings'};
}

1;
