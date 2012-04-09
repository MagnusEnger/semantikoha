#!/usr/bin/perl -w 

# LOAD the URI given as the first argument on the command line
# Synopsis: load.pl <uri>

use lib '../';

use Koha::SPARQL qw( :update );
use Modern::Perl;

my $newuri = '';

if ($ARGV[0]) {
  $newuri = $ARGV[0];
} else {
  die "No URI given\n";
}

verbose_load($newuri);
