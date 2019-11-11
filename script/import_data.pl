#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Logger qw(get_logger);
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
my $db = $pg->db;
my %areas = map { $_->{name} => $_->{id} }
            @{ $pg->db->select('area', [qw<id name>])->hashes };

eval {
    my $tx = $db->begin();
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
            #my $area    = $line->{'EIXO_TEMÁTICO'};
            #my $area_id = $areas{$area} or $logger->logdie("Area '$area' doesn't exists");
            $sql_query .= "(?, ?, ?, ?), ";
            push @binds, @{$line}{qw(Indicador Nome Tema Base)};
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
            push @binds, ($line->{'Id '}, @{$line}{qw(Indicador Nome Classificador)});
        }
        close $csv;

        $sql_query =~ s{, $}{};
        $sql_query .= " ON CONFLICT (id, indicator_id) DO UPDATE SET description = EXCLUDED.description";

        $pg->db->query($sql_query, @binds);
        $logger->info("Subindicators loaded!");
    }

    {
        $logger->info("Loading data...");
        my $member = $zip->memberNamed('dados.csv') or $logger->logdie("File 'dados.csv' not found");
        my $tmp = tmpnam();
        on_scope_exit { unlink $tmp };
        $member->extractToFileNamed($tmp);

        $logger->debug("Creating temporary table...");
        $db->query("CREATE TEMPORARY TABLE bulk ( LIKE data INCLUDING ALL )");
        $logger->debug("Temporary table created!");

        $logger->debug("Sending a COPY...");
        $db->query(<<'SQL_QUERY');
          COPY bulk
            (id, locale_id, indicator_id, subindicator_id, year, area_id)
          FROM STDIN
          WITH CSV QUOTE '"' ENCODING 'UTF-8'
SQL_QUERY

        my $csv = Tie::Handle::CSV->new($tmp, header => 1);
        while (my $line = <$csv>) {
            $line = { %$line };
            delete $line->{Tema};
            my $year = delete $line->{Ano};
            my $indicator_id = delete $line->{Indicador};
            my $locale_id = delete $line->{Localidade};

            while (my ($k, $v) = each(%{$line})) {
                defined $v && length($v) > 0 or next;

                my $subindicator_id;
                if ($k eq 'D0') {
                    $subindicator_id = undef;
                }

                #use DDP;
                #p [$k, $v];
            }
            p $line;
        }
        #p $pg->db->dbh->pg_putcopydata();
    }
};
if ($@) {
    $logger->fatal($@);
    exit 255;
}
