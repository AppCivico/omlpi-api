#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

#use Andi::Logger qw(get_logger);
use Andi::Logger;
use Andi::DatabaseConnection;

use Tie::Handle::CSV;
use Scope::OnExit;
#use Text::CSV;
use Archive::Zip;
use Archive::Zip::MemberRead;
use File::Temp qw(:POSIX);
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
$logger->info("File uncompressed!");

$logger->info("Loading areas");
my $pg = get_mojo_pg();
my %areas = map { $_->{name} => $_->{id} }
            @{ $pg->db->select('area', [qw<id name>])->hashes };

{
    $logger->info("Loading indicators...");
    my $member = $zip->memberNamed('indicadores.csv') or $logger->logdie("File 'indicadores.csv' not found");
    my $tmp = tmpnam();
    on_scope_exit { unlink $tmp };
    $member->extractToFileNamed($tmp);

    my $sql_query = 'INSERT INTO indicator (id, description, area_id, base) VALUES ';
    my @binds = ();
    my $csv = Tie::Handle::CSV->new($tmp, header => 1);
    while (my $line = <$csv>) {
        my $area    = $line->{'EIXO_TEMÁTICO'};
        my $area_id = $areas{$area} or $logger->logdie("Area '$area' doesn't exists");

        $sql_query .= "(?, ?, ?, ?), ";
        push @binds, @{$line}{qw(ID DESCRIÇÃO)}, $area_id, $line->{BASE};
    }
    close $csv;

    $sql_query =~ s{, $}{};
    $sql_query .= " ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description, base = EXCLUDED.base";

    $pg->db->query($sql_query, @binds);
    $logger->info("Indicators loaded!");
}

{
    $logger->info("Loading subindicators...");
    my $member = $zip->memberNamed('desagregadores.csv') or $logger->logdie("File 'desagregadores.csv' not found");
    my $tmp = tmpnam();
    on_scope_exit { unlink $tmp };
    $member->extractToFileNamed($tmp);

    my $sql_query = 'INSERT INTO subindicator (id, indicator_id, description, classification) VALUES ';
    my @binds = ();
    my $csv = Tie::Handle::CSV->new($tmp, header => 1);
    while (my $line = <$csv>) {
        $sql_query .= '(?, ?, ?, ?), ';
        push @binds, @{$line}{qw(ID ID_INDICADOR DESCRIÇÃO CLASSIFICAÇÃO)};
    }
    close $csv;

    $sql_query =~ s{, $}{};
    $sql_query .= " ON CONFLICT (id, indicator_id) DO UPDATE SET description = EXCLUDED.description";

    $pg->db->query($sql_query, @binds);
    $logger->info("Subindicators loaded!");
}
