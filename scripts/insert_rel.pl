#!/usr/bin/perl -w 

# Insert URI1 sameAs URI2 into the enh_graph 
# Synopsis: insert_sameas.pl <uri1> <uri2>

use lib '../';

use Koha::SPARQL qw( :DEFAULT :update get_prefixes );
use Data::Validate::URI qw( is_uri );
use Getopt::Long;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;

my ($prefixes, $relations) = get_prefixes();

my $usage = "Usage: perl insert_sameas.pl <uri1> <rel> <uri2>\n";

my ($debug) = get_options();

if ( !$ARGV[0] || !$ARGV[1] ) {
  print "Not enough data given!\n";
  print "Available relations:\n";
  foreach my $key (keys %{$relations}) {
    print "\t$key : " . $relations->{$key}->{'rel'} . " - " . $relations->{$key}->{'inv'} . "\n";
  }
  print "$usage";
  exit;
}

my $uri1 = $ARGV[0];
my $rel  = $ARGV[1];
my $uri2 = $ARGV[2];

if( !is_uri( $uri1 ) ) {
  print "$uri1 does not look like a URI!\n$usage";
  exit;
}
if( !is_uri( $uri2 ) ) {
  print "$uri2 does not look like a URI!\n$usage";
  exit;
}
if( !$relations->{$rel} ) {
  print "$rel is not recognized as a valid relation!\n";
  exit;
}

my $args = {
  'prefixes'  => $prefixes, # Bit of a hack, just include them all
  'uri1'      => $uri1,
  'rel'       => $relations->{$rel}->{'rel'}, 
  'inv'       => $relations->{$rel}->{'inv'}, 
  'uri2'      => $uri2,
  'relations' => $relations,  
};

my $query = get_query('insert_rel.query', $args);
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
