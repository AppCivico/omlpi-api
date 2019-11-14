#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Logger qw(get_logger);
use Andi::DatabaseConnection;

use Tie::Handle::CSV;
use Scope::OnExit;
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

        my $sql_query = 'INSERT INTO subindicator (id, description, classification) VALUES ';
        my @binds = ();
        my $csv = Tie::Handle::CSV->new($tmp, header => 1);
        my %unique_subindicator;
        while (my $line = <$csv>) {
            my $description = $line->{Nome};
            next if $unique_subindicator{$description}++;
            $sql_query .= '(?, ?, ?), ';
            push @binds, @{$line}{qw(Id Nome Classificador)};
        }
        close $csv;

        $sql_query =~ s{, $}{};
        $sql_query .= " ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description";

        $pg->db->query($sql_query, @binds);
        $logger->info("Subindicators loaded!");
    }

    {
        $logger->info("Loading data...");
        my $member = $zip->memberNamed('dados.csv') or $logger->logdie("File 'dados.csv' not found");
        my $tmp = tmpnam();
        on_scope_exit { unlink $tmp };
        $member->extractToFileNamed($tmp);

        $logger->info("Loading indicator data...");

        $logger->debug("Creating indicator_locale_bulk temporary table...");
        $db->query("CREATE TEMPORARY TABLE indicator_locale_bulk ( LIKE indicator_locale INCLUDING ALL )");

        $logger->debug("COPY to indicator_locale_bulk...");
        $db->query(<<'SQL_QUERY');
          COPY indicator_locale_bulk
            (indicator_id, locale_id, year, value_relative, value_absolute)
          FROM STDIN
          WITH CSV QUOTE '"' ENCODING 'UTF-8'
SQL_QUERY

        my $dbh = $db->dbh;
        my $csv = Tie::Handle::CSV->new($tmp, header => 1);
        my $text_csv = *$csv->{opts}{csv_parser};
        $text_csv->eol("\n");
        while (my $line = <$csv>) {
            $line = { %$line };
            my $area_id      = delete $line->{Tema};
            my $year         = delete $line->{Ano};
            my $indicator_id = delete $line->{Indicador};
            my $locale_id    = delete $line->{Localidade};

            # Get indicator values
            my $value_relative = $line->{'D0_R'};
            my $value_absolute = $line->{'D0_A'};

            # Insert data
            $text_csv->combine($indicator_id, $locale_id, $year, $value_relative, $value_absolute);
            $dbh->pg_putcopydata($text_csv->string());
        }
        $dbh->pg_putcopyend() or $logger->logdie("Error on pg_putcopyend()");
        $logger->debug("COPY ended!");

        $logger->debug("Copying rows from indicator_locale_bulk to indicator_locale");
        $db->query(<<'SQL_QUERY');
          INSERT INTO indicator_locale (indicator_id, locale_id, year, value_relative, value_absolute)
          SELECT indicator_id, locale_id, year, value_relative, value_absolute FROM indicator_locale_bulk
          ON CONFLICT (indicator_id, locale_id, year)
            DO UPDATE
            SET value_relative = EXCLUDED.value_relative,
                value_absolute = EXCLUDED.value_absolute
SQL_QUERY
        $logger->info("Indicators data loaded!");

        # Subindicators values
        $logger->debug("Creating subindicator_locale_bulk temporary table...");
        $db->query("CREATE TEMPORARY TABLE subindicator_locale_bulk ( LIKE subindicator_locale INCLUDING ALL )");

        $logger->debug("COPY to subindicator_locale_bulk...");
        $db->query(<<'SQL_QUERY');
          COPY subindicator_locale_bulk
            (indicator_id, subindicator_id, locale_id, year, value_relative, value_absolute)
          FROM STDIN
          WITH CSV QUOTE '"' ENCODING 'UTF-8'
SQL_QUERY

        seek($csv, 0, 0) or $logger->logdie($!);
        while (my $line = <$csv>) {
            $line = { %$line };
            my $area_id      = delete $line->{Tema};
            my $year         = delete $line->{Ano};
            my $indicator_id = delete $line->{Indicador};
            my $locale_id    = delete $line->{Localidade};

            my %subindicators = map { s{(_[RA])$}{}; $_ => 1 } grep { m{^D} } keys %{$line};
            for my $k (keys %subindicators) {
                my ($subindicator_id) = $k =~ m{^D([0-9]+)};
                next if $subindicator_id == 0;

                # Get indicator values
                my $value_relative = $line->{"D${subindicator_id}_R"};
                my $value_absolute = $line->{"D${subindicator_id}_A"};

                # Insert data
                p [$indicator_id, $subindicator_id, $locale_id, $year, $value_relative, $value_absolute];
                $text_csv->combine($indicator_id, $subindicator_id, $locale_id, $year, $value_relative, $value_absolute);
                $dbh->pg_putcopydata($text_csv->string());
            }
        }
        $dbh->pg_putcopyend() or $logger->logdie("Error on pg_putcopyend()");
        $logger->debug("COPY ended!");
    }
    $tx->commit();
    $logger->info("Data loaded!");
};
if ($@) {
    $logger->fatal($@);
    exit 255;
}


