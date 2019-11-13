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

        $logger->debug("Sending a COPY...");
        $db->query(<<'SQL_QUERY');
          COPY indicator_locale_bulk
            (indicator_id, locale_id, year, value_relative, value_absolute)
          FROM STDIN
          WITH CSV QUOTE '"' ENCODING 'UTF-8'
SQL_QUERY

        my $dbh = $db->dbh;
        my $csv = Tie::Handle::CSV->new($tmp, header => 1);
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
            my $text_csv = *$csv->{opts}{csv_parser};
            $text_csv->eol("\n");

            $text_csv->combine($indicator_id, $locale_id, $year, $value_relative, $value_absolute);
            $dbh->pg_putcopydata($text_csv->string());

            #my %subindicators = map { s{(_[RA])$}{}; $_ => 1 } grep { m{^D} } keys %{$line};

            #for my $k (keys %subindicators) {
            #    my ($subindicator_id) = $k =~ m{^D([0-9]+)};
            #    next if $subindicator_id == 0;
            #}

            #while (my ($k, $v) = each(%{$line})) {
            #    defined $v && length($v) > 0 or next;
 #
            #    # TODO Handle the new columns and remove this next call
            #    next if $k =~ m{00};
 #
            #    my $subindicator_id;
            #    $subindicator_id = $1 if $k =~ m{^D(\d+)$};
            #    $subindicator_id = undef if $k eq 'D0';
 #
            #    my $text_csv = *$csv->{opts}{csv_parser};
            #    $text_csv->eol("\n");
            #    # TODO Handle area_id
            #    $text_csv->combine($locale_id, $indicator_id, $subindicator_id, $year, 1);
 #
            #    $dbh->pg_putcopydata($text_csv->string());
            #}
        }
        $dbh->pg_putcopyend() or $logger->logdie("Error on pg_putcopyend()");
        $logger->debug("Copying rows from indicator_locale_bulk to indicator_locale");
        $db->query(<<'SQL_QUERY');
          INSERT INTO indicator_locale (indicator_id, locale_id, year, value_relative, value_absolute)
          SELECT indicator_id, locale_id, year, value_relative, value_absolute FROM indicator_locale_bulk
SQL_QUERY
        $logger->info("Indicators data loaded!");

        # TODO Avoid data duplication
        #$logger->debug("Copying data from temporary table to data table...");
        #$db->query(<<'SQL_QUERY');
        #  INSERT INTO data
        #    (locale_id, indicator_id, subindicator_id, year, area_id)
        #  SELECT
        #    locale_id, indicator_id, subindicator_id, year, area_id
        #  FROM bulk
#SQL_QUERY
    }
    $tx->commit();
    $logger->info("Data loaded!");
};
if ($@) {
    $logger->fatal($@);
    exit 255;
}
