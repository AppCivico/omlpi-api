#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

#use Andi::Logger qw(get_logger);
use Andi::Logger;
use Andi::DatabaseConnection;

use Text::CSV;
use Archive::Zip;
use Archive::Zip::MemberRead;
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
#my @members = $zip->members;
$logger->debug("File uncompressed!");

{
    my $member = $zip->memberNamed('indicators.csv');
    my $fh = $member->readFileHandle();
    my $csv = Text::CSV->new({eol => "\n"});
    #while (defined(my $line = $fh->getline())) {
    while (my $line = $csv->getline($fh)) {
        p $line;
    }
    $fh->close();
}
