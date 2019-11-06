#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

#use Andi::Logger qw(get_logger);
use Andi::Logger;
use Andi::DatabaseConnection;

use Archive::Zip;
use Data::Printer;

my $logger = get_logger();

$logger->info("Starting data import...");
my $dataset = $ARGV[0];

my $filepath = "$RealBin/../dataset/${dataset}";
if (!-e $filepath) {
    $logger->logdie("File '$filepath' not found.");
}

$logger->info("Uncompressing file '$dataset'...");
my $zip = Archive::Zip->new($filepath);
my @members = $zip->members;
$logger->debug("File uncompressed!");

{
    $logger->info("Processing indicators.csv...");
    my ($member) = grep { $_->{fileName} eq 'indicators.csv' } @members
      or $logger->logdie("File 'indicators.csv' is not present in zip file '$dataset'.");

    my $fh;
    $member->extractToFileHandle($fh);
}
