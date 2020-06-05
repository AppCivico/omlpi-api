#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Logger qw(get_logger);
use OMLPI::DatabaseConnection;

use Text::CSV;
use Tie::Handle::CSV;
use Scope::OnExit;
use Archive::Zip;
use File::Temp qw(:POSIX);
use Data::Printer;
use Data::Dumper;
use OMLPI::Utils qw(nullif trim);
use Digest::MD5;

my $logger = get_logger();

$logger->info("Starting data import...");
my $dataset = 'latest';

my $filepath = "$RealBin/../resources/dataset/${dataset}";
if (!-e $filepath) {
    $logger->logdie("File '$filepath' not found.");
}

$logger->info("Getting the file checksum");
open my $fh, '<', $filepath or $logger->logdie($!);
binmode ($fh);
my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
close $fh;
$logger->info("Dataset checksum: $checksum");

# Get the last database update checksum
my $pg = get_mojo_pg();
my $db = $pg->db;
my $last_checksum = $db->query("select value from config where name = 'DATASET_CHECKSUM'")->hash;
if (defined($last_checksum)) {
    my $last_checksum_value = $last_checksum->{value};
    $logger->info(sprintf "Last checksum: $last_checksum_value");
    if ($checksum eq $last_checksum_value) {
        $logger->info("There is nothing to update on your database!");
        exit 0;
    }
}
$logger->info("New dataset! Let's import data!");

$logger->info("Uncompressing file '$dataset'...");
my $zip = Archive::Zip->new($filepath);
$logger->info("File uncompressed!");

$logger->info("Loading areas");
my %areas = map { $_->{name} => $_->{id} }
            @{ $pg->db->select('area', [qw<id name>])->hashes };

my %locales = map { $_->{id} => 1 }
            @{ $pg->db->select('locale', [qw(id)])->hashes };

eval {
    my $tx = $db->begin();
    {
        my $file = 'indicadores.csv';
        $logger->info("Loading indicators...");
        my $member = $zip->memberNamed($file) or $logger->logdie("File '${file}' not found");
        my $tmp = tmpnam();
        on_scope_exit { unlink $tmp };
        $member->extractToFileNamed($tmp);

        my $sql_query = 'INSERT INTO indicator (id, description, area_id, base, ods, concept) VALUES ';
        my @binds = ();
        my $csv = Tie::Handle::CSV->new($tmp, header => 1, sep_char => ';');
        while (my $line = <$csv>) {
            my @ods = split m{\D+}, trim($line->{ODS});
            my $ods;
            $ods = '{' . join(',', @ods) . '}' if scalar @ods > 0;

            $sql_query .= "(?, ?, ?, ?, ?, ?), ";
            push @binds, @{$line}{(qw(ID NOME TEMA BASE))}, $ods, $line->{CONCEITO};
        }
        close $csv;

        $sql_query =~ s{, $}{};
        $sql_query .= <<'SQL_QUERY';
          ON CONFLICT (id)
          DO UPDATE
            SET description = EXCLUDED.description,
                base        = EXCLUDED.base,
                area_id     = EXCLUDED.area_id,
                ods         = EXCLUDED.ods,
                concept     = EXCLUDED.concept
SQL_QUERY

        $pg->db->query($sql_query, @binds);
        $logger->info("Indicators loaded!");
    }

    {
        $logger->info("Loading subindicators...");
        my $file = 'desagregadores.csv';
        my $member = $zip->memberNamed($file) or $logger->logdie("File '${file}' not found");
        my $tmp = tmpnam();
        on_scope_exit { unlink $tmp };
        $member->extractToFileNamed($tmp);

        my $sql_query = 'INSERT INTO subindicator (id, description, classification) VALUES ';
        my @binds = ();
        my $csv = Tie::Handle::CSV->new($tmp, header => 1, sep_char => ';');
        my %unique_subindicator;
        while (my $line = <$csv>) {
            my $id = int($line->{ID}) or next;
            next if $id == 0 || $unique_subindicator{$id}++;
            $sql_query .= '(?, ?, ?), ';
            push @binds, ($id, @{$line}{(qw(Nome Classificador))});
        }
        close $csv;

        $sql_query =~ s{, $}{};
        $sql_query .= " ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description";

        $pg->db->query($sql_query, @binds);
        $logger->info("Subindicators loaded!");
    }

    {
        $logger->info("Loading data...");
        my $file = 'dados.csv';
        my $member = $zip->memberNamed($file) or $logger->logdie("File '${file}' not found");
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
        my $csv = Tie::Handle::CSV->new($tmp, header => 1, sep_char => ';');
        #my $text_csv = *$csv->{opts}{csv_parser};
        #$text_csv->eol("\n");
        my $text_csv = Text::CSV->new({
            binary => 1,
            eol    => "\n",
        });

        my %loaded_indicators_data = ();
        while (my $line = <$csv>) {
            $line = { %$line };
            my $area_id      = delete $line->{Tema};
            my $year         = delete $line->{Ano};
            my $indicator_id = delete $line->{Indicador};
            my $locale_id    = delete($line->{Localidade});
            next if $indicator_id == 0;

            if ($indicator_id !~ m{^\d+$} || $locale_id !~ m{^\d+$} || $year !~ m{^\d+$} || $area_id !~ m{^\d+$} ) {
                $logger->error("Há algo de errado com essa linha:\n" . Dumper $line);
                $logger->error("Skipping...");
                next;
            }

            if (!$locales{$locale_id}) {
                $logger->warn(sprintf "A locale id '%d' não existe no banco!", $locale_id);
                next;
            }

            if ($loaded_indicators_data{$locale_id}->{$indicator_id}->{$year}) {
                $logger->warn(sprintf(
                    "O indicador %d já foi carregado para a localidade %d no ano %d!",
                    $indicator_id,
                    $locale_id,
                    $year
                ));
                next;
            }

            # Get indicator values
            my $value_relative = $line->{'D0_R'};
            my $value_absolute = $line->{'D0_A'};

            $value_relative =~ s/\.//g;
            $value_absolute =~ s/\.//g;
            $value_relative =~ s/,/./ if $value_relative =~ m{^[0-9+]+,[0-9]+$};
            $value_absolute =~ s/,/./ if $value_absolute =~ m{^[0-9+]+,[0-9]+$};
            $value_relative = nullif(trim($value_relative), '');
            $value_absolute = nullif(trim($value_absolute), '');
            $value_absolute = sprintf('%.1f', $value_absolute) if defined $value_absolute;
            $value_relative = sprintf('%.1f', $value_relative) if defined $value_relative;
            $value_absolute =~ s/\.0$//                        if defined $value_absolute;
            $value_relative =~ s/\.0$//                        if defined $value_relative;

            # Insert data
            if (defined($value_relative) || defined($value_absolute)) {
                $text_csv->combine($indicator_id, $locale_id, $year, $value_relative, $value_absolute);
                $dbh->pg_putcopydata($text_csv->string());
                $loaded_indicators_data{$locale_id}->{$indicator_id}->{$year} = 1;
            }
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

        # Seek and skip first line
        seek($csv, 0, 0) or $logger->logdie($!);
        <$csv>;
        my %loaded_subindicators_data = ();
        while (my $line = <$csv>) {
            $line = { %$line };
            my $area_id      = delete $line->{Tema};
            my $year         = delete $line->{Ano};
            my $indicator_id = delete $line->{Indicador};
            my $locale_id    = delete $line->{Localidade};
            if (!$locales{$locale_id}) {
                $logger->warn(sprintf "A locale id '%d' não existe no banco!", $locale_id);
                next;
            }

            my %subindicators = map { s{(_[RA])$}{}; $_ => 1 } grep { m{^D} } keys %{$line};
            for my $k (keys %subindicators) {
                my ($subindicator_id) = $k =~ m{^D([0-9]+)};
                next if $subindicator_id == 0;

                if ($loaded_subindicators_data{$locale_id}->{$indicator_id}->{$subindicator_id}->{$year}) {
                    $logger->warn(sprintf(
                        "O desagregador id %d do indicador %d já foi carregado para a localidade %d no ano %d!",
                        $subindicator_id,
                        $indicator_id,
                        $locale_id,
                        $year
                    ));
                    next;
                }

                # Get indicator values
                my $value_relative = $line->{"D${subindicator_id}_R"};
                my $value_absolute = $line->{"D${subindicator_id}_A"};
                $value_relative    =~ s/\.//g;
                $value_absolute    =~ s/\.//g;
                $value_relative    =~ s/,/./ if $value_relative =~ m{^[0-9+]+,[0-9]+$};
                $value_absolute    =~ s/,/./ if $value_absolute =~ m{^[0-9+]+,[0-9]+$};
                $value_relative    = nullif(trim($value_relative), '');
                $value_absolute    = nullif(trim($value_absolute), '');
                $value_absolute    = sprintf('%.1f', $value_absolute) if defined $value_absolute;
                $value_relative    = sprintf('%.1f', $value_relative) if defined $value_relative;
                $value_absolute    =~ s/\.0$//                        if defined $value_absolute;
                $value_relative    =~ s/\.0$//                        if defined $value_relative;

                # Insert data if has data
                if (defined($value_relative) || defined($value_absolute)) {
                    $text_csv->combine($indicator_id, $subindicator_id, $locale_id, $year, $value_relative, $value_absolute);
                    $dbh->pg_putcopydata($text_csv->string());
                    $loaded_subindicators_data{$locale_id}->{$indicator_id}->{$subindicator_id}->{$year} = 1;
                }
            }
        }
        $dbh->pg_putcopyend() or $logger->logdie("Error on pg_putcopyend()");
        $logger->debug("COPY ended!");

        $logger->debug("Copying rows from subindicator_locale_bulk to subindicator_locale");
        $db->query(<<'SQL_QUERY');
          INSERT INTO subindicator_locale (indicator_id, subindicator_id, locale_id, year, value_relative, value_absolute)
          SELECT indicator_id, subindicator_id, locale_id, year, value_relative, value_absolute
          FROM subindicator_locale_bulk
          ON CONFLICT (indicator_id, subindicator_id, locale_id, year)
            DO UPDATE
            SET value_relative = EXCLUDED.value_relative,
                value_absolute = EXCLUDED.value_absolute
SQL_QUERY
        $logger->info("Subindicators data loaded!");
    }

    $logger->info("Updating random_locale_indicator materialized view...");
    $db->query("REFRESH MATERIALIZED VIEW random_locale_indicator");
    $logger->info("Materialized view refreshed!");

    $logger->info("Updating the dataset checksum...");
    $db->query(<<'SQL_QUERY', $checksum);
      INSERT INTO config (name, value) VALUES ('DATASET_CHECKSUM', ?)
      ON CONFLICT (name) WHERE valid_to = 'infinity' DO
        UPDATE SET
          value = EXCLUDED.value,
          valid_to = 'infinity';
SQL_QUERY
    $logger->info("Dataset checksum updated!");

    $tx->commit();
    $logger->info("Data loaded!");
};
if ($@) {
    $logger->fatal($@);
    exit 255;
}


