#!/usr/bin/perl -w 

# LOAD the URI given as the first argument on the command line
# Synopsis: load.pl <uri>

use lib '../';

use Koha::LinkedData::Internal;
use Modern::Perl;

my $newuri = '';

if ($ARGV[0]) {
  $newuri = $ARGV[0];
} else {
  die "No URI given\n";
}

print "Loading $newuri\n";
my $loaded = Koha::LinkedData::Internal::load($newuri);
print "Loaded $loaded triples from $newuri\n";
