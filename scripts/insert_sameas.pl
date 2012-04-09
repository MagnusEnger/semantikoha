#!/usr/bin/perl -w 

# Insert URI1 sameAs URI2 into the enh_graph 
# Synopsis: insert_sameas.pl <uri1> <uri2>

use lib '../';

use Koha::SPARQL qw( :DEFAULT :update );
use Data::Validate::URI qw( is_uri );
use Getopt::Long;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;

my $usage = "Usage: insert_sameas.pl <uri1> <uri2>\n";

my ($debug) = get_options();

if ( !$ARGV[0] || !$ARGV[1] ) {
  print "Not enough URIs given!\n$usage";
  exit;
}

my $uri1 = $ARGV[0];
my $uri2 = $ARGV[1];

if( !is_uri( $uri1 ) ) {
  print "$uri1 does not look like a URI!\n$usage";
  exit;
}
if( !is_uri( $uri2 ) ) {
  print "$uri2 does not look like a URI!\n$usage";
  exit;
}

my $args = {
  'uri1' => $uri1,
  'uri2' => $uri2,
};

my $query = get_query('insert_sameas.query', $args);
print $query if $debug;
my $res = sparql_insert($query);
print Dumper $res if $debug;

# Get commandline options
sub get_options {
  
  my $debug = '';
  my $help  = '';

  GetOptions(
    'd|debug!'  => \$debug,
    'h|?|help'  => \$help
  );
  
  pod2usage(-exitval => 0) if $help;
  return ($debug);
  
}
