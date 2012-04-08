#!/usr/bin/perl -w 

# Find language URIs that have not been LOADed and LOAD them
# Synopsis: language.pl -q influences
# 
# This will look for templates2load.tt and the query will be run 
# against the triplestore and result in a list of URIs that need to
# be LOADed. Then the URIs are loaded. 

use lib '../';

use Koha::LinkedData::Internal;
use Getopt::Long;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;

my ($q, $debug) = get_options();

my $query = Koha::LinkedData::get_query($q . '2load.tt');
my $langs = Koha::LinkedData::get_sparql($query);

foreach my $lang ( @{$langs} ) {

  if ($lang->{'uri'}->{'type'} && $lang->{'uri'}->{'type'} eq 'uri') {
    Koha::LinkedData::Internal::verbose_load($lang->{'uri'}->{'value'});
  }

}

# Get commandline options
sub get_options {
  
  my $q     = '';
  my $debug = '';
  my $help  = '';

  GetOptions(
    'q|query=s' => \$q, 
    'd|debug!'  => \$debug,
    'h|?|help'  => \$help
  );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -q, --query\n", -exitval => 1) if !$q;
  return ($q, $debug);
  
}
