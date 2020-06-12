package OMLPI::Model::Data;
use Mojo::Base 'MojoX::Model';

use Text::CSV;
use Excel::Writer::XLSX;
use File::Temp qw(tempfile);
use Mojo::Util qw(decode);
use OMLPI::Utils qw(mojo_home);
use IPC::Run qw(run);

use Data::Printer;

sub get {
    my ($self, %opts) = @_;

    my $year      = $opts{year};
    my $area_id   = $opts{area_id};
    my $locale_id = $opts{locale_id};
    my @binds     = ((($year) x 6), (($area_id) x 2), (($year) x 2), $locale_id);

    return $self->app->pg->db->query(<<"SQL_QUERY", @binds);
      SELECT
        locale.id,
        CASE
          WHEN locale.type = 'city' THEN CONCAT(locale.name, ', ', state.uf)
          ELSE locale.name
        END AS name,
        locale.type,
        locale.latitude,
        locale.longitude,
        COALESCE(
          (
            SELECT JSON_AGG("all".result)
            FROM (
              SELECT ROW_TO_JSON("row") result
              FROM (
                SELECT
                  indicator.id,
                  indicator.description,
                  indicator.base,
                  indicator.concept,
                  ROW_TO_JSON(area.*) AS area,
                  (
                    SELECT ROW_TO_JSON(indicator_values)
                    FROM (
                      SELECT
                        indicator_locale.year           AS year,
                        indicator_locale.value_relative AS value_relative,
                        indicator_locale.value_absolute AS value_absolute
                      FROM indicator_locale
                        WHERE indicator_locale.indicator_id = indicator.id
                          AND indicator_locale.locale_id = locale.id
                          AND (?::int IS NULL OR indicator_locale.year = ?::int)
                          AND (
                            indicator_locale.value_absolute IS NOT NULL
                            OR indicator_locale.value_relative IS NOT NULL
                          )
                      ORDER BY indicator_locale.year DESC, indicator_locale.indicator_id ASC
                      LIMIT 1
                    ) indicator_values
                  ) AS values,
                  (
                    SELECT JSON_AGG(ods.*)
                    FROM (
                      SELECT *
                      FROM ods
                      WHERE ods.id = ANY(indicator.ods)
                    ) ods
                  ) AS ods,
                  COALESCE(
                    (
                      SELECT ARRAY_AGG(subindicators)
                      FROM (
                        SELECT
                          --DISTINCT ON (classification) subindicator.classification AS classification,
                          subindicator.id,
                          subindicator.classification,
                          subindicator.description,
                          (
                            SELECT ARRAY_AGG(subindicator_values)
                            FROM (
                              SELECT
                                subindicator_locale.year,
                                subindicator_locale.value_relative,
                                subindicator_locale.value_absolute
                              FROM subindicator_locale
                              WHERE subindicator_locale.indicator_id = indicator.id
                                AND subindicator_locale.subindicator_id = subindicator.id
                                AND subindicator_locale.locale_id = locale.id
                                AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                              ORDER BY subindicator_locale.year DESC, subindicator_locale.indicator_id ASC
                            ) subindicator_values
                          ) AS values
                        FROM subindicator_locale
                        JOIN subindicator
                          ON subindicator.id = subindicator_locale.subindicator_id
                        WHERE subindicator_locale.locale_id = locale.id
                          AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                        GROUP BY subindicator.id, subindicator.classification, subindicator.description
                      ) AS subindicators
                    ),
                    ARRAY[]::record[]
                  ) AS subindicators
                FROM indicator
                JOIN area
                  ON area.id = indicator.area_id
                WHERE (?::text IS NULL OR area.id = ?::int)
                  AND EXISTS (
                    SELECT 1
                    FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id = locale.id
                      AND (?::int IS NULL OR indicator_locale.year = ?::int)
                  )
                ORDER BY indicator.id
              ) AS "row"
            ) "all"
          ),
          '[]'::json
        ) AS indicators
      FROM locale
      LEFT JOIN city
        ON locale.type = 'city' AND locale.id = city.id
      LEFT JOIN state
        ON locale.type = 'city' AND city.state_id = state.id
      WHERE locale.id = ?
      GROUP BY 1,2,3
SQL_QUERY
}

sub compare {
    my ($self, %opts) = @_;

    my $year       = $opts{year};
    my $area_id    = $opts{area_id};
    my $locale_id  = $opts{locale_id};
    my @locale_ids = @{ $self->app->model('Locale')->get_locales_of_the_same_scope($locale_id) };
    my @binds      = ((($year) x 8), (($area_id) x 2), (($year) x 2), @locale_ids);

    return $self->app->pg->db->query(<<"SQL_QUERY", @binds);
      SELECT
        locale.id   AS id,
        locale.name AS name,
        locale.type AS type,
        COALESCE(
          (
            SELECT JSON_AGG("all".result)
            FROM (
              SELECT ROW_TO_JSON("row") result
              FROM (
                SELECT
                  indicator.id,
                  indicator.description,
                  indicator.base,
                  indicator.concept,
                  ROW_TO_JSON(area.*) AS area,
                  (
                    SELECT ARRAY_AGG(indicator_values)
                    FROM (
                      SELECT
                        indicator_locale.year           AS year,
                        indicator_locale.value_relative AS value_relative,
                        indicator_locale.value_absolute AS value_absolute
                      FROM indicator_locale
                        WHERE indicator_locale.indicator_id = indicator.id
                          AND indicator_locale.locale_id = locale.id
                          AND (?::int IS NULL OR indicator_locale.year = ?::int)
                          AND (
                            indicator_locale.value_absolute IS NOT NULL
                            OR indicator_locale.value_relative IS NOT NULL
                          )
                      ORDER BY indicator_locale.year DESC
                    ) indicator_values
                  ) AS values,
                  COALESCE(
                    (
                      SELECT ARRAY_AGG(subindicators)
                      FROM (
                        SELECT
                          DISTINCT(subindicator.classification) AS classification,
                          COALESCE(
                            (
                              SELECT ARRAY_AGG(sx)
                              FROM (
                                SELECT
                                  s2.id,
                                  s2.description,
                                  (
                                    SELECT ARRAY_AGG(sl)
                                    FROM (
                                      SELECT
                                        subindicator_locale.year,
                                        subindicator_locale.value_relative,
                                        subindicator_locale.value_absolute
                                      FROM subindicator_locale
                                      WHERE subindicator_locale.indicator_id = indicator.id
                                        AND subindicator_locale.subindicator_id = s2.id
                                        AND subindicator_locale.locale_id = locale.id
                                        AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                        AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                                      ORDER BY subindicator_locale.year DESC
                                    ) sl
                                  ) AS values
                                FROM subindicator s2
                                WHERE subindicator.classification = s2.classification
                                  AND EXISTS (
                                    SELECT 1 FROM subindicator_locale
                                    WHERE subindicator_locale.subindicator_id = s2.id
                                      AND subindicator_locale.indicator_id = indicator.id
                                      AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                      AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                                  )
                                ORDER BY s2.id
                              ) sx
                            ),
                            ARRAY[]::record[]
                          ) AS data
                        FROM subindicator
                        WHERE EXISTS (
                          SELECT 1
                          FROM subindicator_locale
                          WHERE subindicator_locale.subindicator_id = subindicator.id
                            AND subindicator_locale.indicator_id = indicator.id
                            AND subindicator_locale.locale_id = locale.id
                            AND (
                              subindicator_locale.value_relative IS NOT NULL
                              OR subindicator_locale.value_absolute IS NOT NULL
                            )
                            AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                        )
                      ) AS subindicators
                    ),
                    ARRAY[]::record[]
                  ) AS subindicators
                FROM indicator
                JOIN area
                  ON area.id = indicator.area_id
                WHERE (?::text IS NULL OR area.id = ?::int)
                  AND EXISTS (
                    SELECT 1
                    FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id = locale.id
                      AND (?::int IS NULL OR indicator_locale.year = ?::int)
                  )
                ORDER BY indicator.id
              ) AS "row"
            ) "all"
          ),
          '[]'::json
        ) AS indicators
      FROM locale
      WHERE locale.id IN (@{[join ',', map '?', @locale_ids]})
      GROUP BY 1,2,3
SQL_QUERY
}

sub compare_country {
    my ($self, %opts) = @_;

    my $year       = $opts{year};
    my $area_id    = $opts{area_id};
    my $locale_id  = $opts{locale_id};
    my @locale_ids = (
        0,
        @{ $self->app->model('Locale')->get_regions_of_a_country($locale_id)
            ->hashes
            ->map(sub { $_->{id} } )
            ->to_array()
        }
    );

    my @binds = ((($year) x 8), (($area_id) x 2), (($year) x 2), @locale_ids);

    return $self->app->pg->db->query(<<"SQL_QUERY", @binds);
      SELECT
        locale.id   AS id,
        locale.name AS name,
        locale.type AS type,
        COALESCE(
          (
            SELECT JSON_AGG("all".result)
            FROM (
              SELECT ROW_TO_JSON("row") result
              FROM (
                SELECT
                  indicator.id,
                  indicator.description,
                  indicator.base,
                  indicator.concept,
                  ROW_TO_JSON(area.*) AS area,
                  (
                    SELECT ARRAY_AGG(indicator_values)
                    FROM (
                      SELECT
                        indicator_locale.year           AS year,
                        indicator_locale.value_relative AS value_relative,
                        indicator_locale.value_absolute AS value_absolute
                      FROM indicator_locale
                        WHERE indicator_locale.indicator_id = indicator.id
                          AND indicator_locale.locale_id = locale.id
                          AND (?::int IS NULL OR indicator_locale.year = ?::int)
                          AND (
                            indicator_locale.value_absolute IS NOT NULL
                            OR indicator_locale.value_relative IS NOT NULL
                          )
                      ORDER BY indicator_locale.year DESC, indicator_locale.indicator_id ASC
                    ) indicator_values
                  ) AS values,
                  COALESCE(
                    (
                      SELECT ARRAY_AGG(subindicators)
                      FROM (
                        SELECT
                          DISTINCT(subindicator.classification) AS classification,
                          COALESCE(
                            (
                              SELECT ARRAY_AGG(sx)
                              FROM (
                                SELECT
                                  s2.id,
                                  s2.description,
                                  (
                                    SELECT ARRAY_AGG(sl)
                                    FROM (
                                      SELECT
                                        subindicator_locale.year,
                                        subindicator_locale.value_relative,
                                        subindicator_locale.value_absolute
                                      FROM subindicator_locale
                                      WHERE subindicator_locale.indicator_id = indicator.id
                                        AND subindicator_locale.subindicator_id = s2.id
                                        AND subindicator_locale.locale_id = locale.id
                                        AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                        AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                                      ORDER BY subindicator_locale.year DESC, subindicator_locale.subindicator_id ASC
                                    ) sl
                                  ) AS values
                                FROM subindicator s2
                                WHERE subindicator.classification = s2.classification
                                  AND EXISTS (
                                    SELECT 1 FROM subindicator_locale
                                    WHERE subindicator_locale.subindicator_id = s2.id
                                      AND subindicator_locale.indicator_id = indicator.id
                                      AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                      AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                                  )
                              ) sx
                            ),
                            ARRAY[]::record[]
                          ) AS data
                        FROM subindicator
                        WHERE EXISTS (
                          SELECT 1
                          FROM subindicator_locale
                          WHERE subindicator_locale.subindicator_id = subindicator.id
                            AND subindicator_locale.indicator_id = indicator.id
                            AND subindicator_locale.locale_id = locale.id
                            AND (
                              subindicator_locale.value_relative IS NOT NULL
                              OR subindicator_locale.value_absolute IS NOT NULL
                            )
                            AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                        )
                      ) AS subindicators
                    ),
                    ARRAY[]::record[]
                  ) AS subindicators
                FROM indicator
                JOIN area
                  ON area.id = indicator.area_id
                WHERE (?::text IS NULL OR area.id = ?::int)
                  AND EXISTS (
                    SELECT 1
                    FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id = locale.id
                      AND (?::int IS NULL OR indicator_locale.year = ?::int)
                  )
                ORDER BY indicator.id
              ) AS "row"
            ) "all"
          ),
          '[]'::json
        ) AS indicators
      FROM locale
      WHERE locale.id IN (@{[join ',', map '?', @locale_ids]})
      GROUP BY 1,2,3
SQL_QUERY
}

sub get_max_year {
    my ($self, %opts) = @_;

    my $locale_id = $opts{locale_id};
    my @binds = (($locale_id) x 4);

    return $self->app->pg->db->query(<<"SQL_QUERY", @binds);
      SELECT MAX(years.max) AS year
      FROM (
        SELECT MAX(year)
        FROM indicator_locale
        WHERE (?::int IS NULL OR locale_id = ?)
        UNION SELECT MAX(year)
        FROM subindicator_locale
        WHERE (?::int IS NULL OR locale_id = ?)
      ) years
SQL_QUERY
}

sub get_resume {
    my ($self, %opts) = @_;

    # Get template
    my $home = mojo_home();
    my $template = $home->rel_file('resources/resume/index.html')->to_abs;
    my $mt = Mojo::Template->new(vars => 1);

    # Fix encoding issues
    my $slurp = decode('UTF-8', $template->slurp);

    my $log = $self->app->log;

    # Create temporary directory
    my $dir = File::Temp->newdir(CLEANUP => 1);
    $log->debug("Temporary dir: " . $dir->dirname);

    $log->debug('Creating symlinks...');
    symlink $home->rel_file("resources/resume/$_"), $dir->dirname . "/$_"
      or die $!
        for qw<css img>;

    # Create temporary file
    $log->debug('Creating temporary file...');
    my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.html', DIR => $dir->dirname);
    binmode $fh, ':utf8';
    $log->debug('Temporary file: ' . $fh->filename);

    # Get indicator values
    my $locale_id = $opts{locale_id};
    my $year = $self->get_max_year(locale_id => $locale_id)->hash->{year};
    my $indicator_values = $self->app->pg->db->query(<<"SQL_QUERY", $locale_id, $year);
      select indicator_id, value_absolute, value_relative
      from indicator_locale
      where locale_id = ? and year = ?
SQL_QUERY
    my $subindicator_values = $self->app->pg->db->query(<<"SQL_QUERY", $locale_id, $year);
      select indicator_id, subindicator_id, value_absolute, value_relative
      from subindicator_locale
      where locale_id = ? and year = ?
SQL_QUERY

    # Get locale
    my $locale = $self->app->pg->db->query(<<'SQL_QUERY', $locale_id)->hash;
       select
        case
          when type = 'city' then locale.name || '/' || state.uf
          else locale.name
        end as name
      from locale
      left join city
        on city.id = locale.id
      left join state
        on city.state_id = state.id
      where locale.id = ?
SQL_QUERY

    my %data = (
        locale_name => $locale->{name},
        year        => $year,
        (
            map {
                (
                    sprintf('%d-D0_A', $_->{indicator_id}) => $_->{value_absolute} // 'N/A',
                    sprintf('%d-D0_R', $_->{indicator_id}) => $_->{value_relative} // 'N/A',
                )
            } $indicator_values->hashes()->each()
        ),
        (
            map {
                (
                    sprintf('%d-D%d_A', $_->{indicator_id}, $_->{subindicator_id}) => $_->{value_absolute} // 'N/A',
                    sprintf('%d-D%d_R', $_->{indicator_id}, $_->{subindicator_id}) => $_->{value_relative} // 'N/A',
                )
            } $subindicator_values->hashes()->each()
        ),
    );

    # Write to file
    $log->debug('Rendering the file...');
    print $fh $mt->render($slurp, {
        now         => $self->app->model('DateTime')->now(),
        locale_name => $locale->{name},
        year        => $year,
        data        => \%data,
    });
    close $fh;

    # Generate another temporary file
    $log->debug('Running wkhtmltopdf...');
    my (undef, $pdf_file) = tempfile(SUFFIX => '.pdf');
    my $out;
    my $err;
    run [
        #'xvfb-run', '--auto-servernum', '--server-num=1', '--server-args="-screen 0 1024x768x24"',
        'xvfb-run',
        'wkhtmltopdf', qw(-T 10 -B 10 -L 0 -R 0),
        $fh->filename,
        $pdf_file,
    ], \undef, \$out, \$err;

    $log->debug('STDOUT:');
    $log->debug($out);
    $log->debug('STDERR:');
    $log->debug($err);

    return $pdf_file;
}

sub get_all_data {
    my $self = shift;

    my $query = $self->app->pg->db->query_p(<<'SQL_QUERY');
      SELECT
        locale.id             AS locale_id,
        locale.name           AS locale_name,
        area.name             AS area_name,
        indicator.id          AS indicator_id,
        indicator.description AS indicator_description,
        indicator_locale.year AS indicator_value_year,
        indicator_locale.value_relative AS indicator_value_relative,
        indicator_locale.value_absolute AS indicator_value_absolute,
        s.*
      FROM locale
      JOIN indicator_locale
        ON locale.id = indicator_locale.locale_id
      JOIN indicator
        ON indicator.id = indicator_locale.indicator_id
      JOIN area
        ON area.id = indicator.area_id
      INNER JOIN LATERAL (
        SELECT
          indicator.id                       AS indicator_id,
          subindicator.description           AS subindicator_description,
          subindicator.id                    AS subindicator_id,
          subindicator.classification        AS subindicator_classification,
          subindicator_locale.value_relative AS subindicator_value_relative,
          subindicator_locale.value_absolute AS subindicator_value_absolute,
          subindicator_locale.year           AS subindicator_year
        FROM subindicator_locale
        JOIN subindicator
          ON subindicator.id = subindicator_locale.id
        WHERE subindicator_locale.locale_id = locale.id
        UNION
        SELECT
          indicator.id AS indicator_id,
          NULL AS subindicator_id,
          NULL AS subindicator_description,
          NULL AS subindicator_classification,
          NULL AS subindicator_value_absolute,
          NULL AS subindicator_value_relative,
          NULL AS subindicator_year
      ) s ON s.indicator_id = indicator.id
      ORDER BY (
        CASE locale.type
          WHEN 'country' THEN 1
          WHEN 'region'  THEN 2
          WHEN 'state'   THEN 3
          WHEN 'city'    THEN 4
        END
      ),
      locale.name, indicator.id, indicator_locale.year DESC, (s.subindicator_id IS NULL) DESC, s.subindicator_year
SQL_QUERY

    return $query->then(sub {
        my $res = shift;

        # Create temporary file
        my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.xlsx');

        # Spreadsheet
        my $workbook = Excel::Writer::XLSX->new($fh->filename);
        $workbook->set_optimization();

        # Formats
        my $header_format = $workbook->add_format();
        $header_format->set_bold();

        # Write data
        my %worksheets  = ();
        my %has_headers = ();
        my %lines       = ();
        while (my $r = $res->hash) {
            # Get or create worksheet
            my $year = $r->{indicator_value_year};
            my $worksheet = $worksheets{$year};
            if (!defined($worksheet)) {
                $worksheets{$year} = $worksheet = $workbook->add_worksheet($year);
            }

            # Write headers if hasn't
            $lines{$year} //= 0;
            if (!$has_headers{$year}++) {
                my @headers = (
                    qw(LOCALIDADE TEMA INDICADOR), 'VALOR RELATIVO', 'VALOR ABSOLUTO', qw(DESAGREGADOR CLASSIFICAÇÃO),
                    'VALOR RELATIVO', 'VALOR ABSOLUTO',
                );
                for (my $i = 0; $i < scalar @headers; $i++) {
                    $worksheet->write($lines{$year}, $i, $headers[$i], $header_format);
                }
                $lines{$year}++;
            }

            # Write lines
            my @keys = qw(
                locale_name area_name indicator_description indicator_value_relative indicator_value_absolute
                subindicator_description subindicator_classification subindicator_value_relative
                subindicator_value_absolute
            );
            for (my $i = 0; $i < scalar @keys; $i++) {
                $worksheet->write($lines{$year}, $i, $r->{$keys[$i]});
            }
            $lines{$year}++;
        }

        close $fh;

        return $fh;
    });
}

sub download_indicator {
    my ($self, %opts) = @_;

    my $year         = $opts{year};
    my $locale_id    = $opts{locale_id};
    my $indicator_id = $opts{indicator_id};

    my $query_p = $self->app->pg->db->query_p(<<'SQL_QUERY', $indicator_id, $locale_id, $year);
      SELECT
        locale.name                      AS locale_name,
        indicator.description            AS indicator_description,
        indicator_locale.year            AS year,
        area.name                        AS area_name,
        indicator_locale.value_relative  AS average_relative,
        indicator_locale.value_absolute  AS average_absolute,
        subs.description                 AS subindicator_description,
        subs.classification              AS subindicator_classification,
        subs.value_relative              AS subindicator_value_relative,
        subs.value_absolute              AS subindicator_value_absolute,
        indicator.base                   AS base,
        indicator.concept                AS concept
      FROM indicator_locale
      JOIN indicator
        ON indicator_locale.indicator_id = indicator.id
      JOIN area
        ON area.id = indicator.area_id
      JOIN locale
        ON locale.id = indicator_locale.locale_id
      LEFT JOIN LATERAL (
        SELECT
          subindicator.description,
          subindicator.classification,
          subindicator_locale.value_absolute,
          subindicator_locale.value_relative,
          subindicator_locale.indicator_id
        FROM subindicator_locale
        JOIN subindicator
          ON subindicator.id = subindicator_locale.subindicator_id
        WHERE subindicator_locale.locale_id = locale.id
        ORDER BY subindicator_locale.indicator_id, subindicator_locale.subindicator_id
      ) subs ON subs.indicator_id = indicator.id
      WHERE indicator.id = ?
        AND indicator_locale.locale_id = ?
        AND indicator_locale.year = ?
      ORDER BY indicator.id
SQL_QUERY

    my $locale_p = $self->app->pg->db->select_p("locale", [qw(name)], { id => $locale_id });

    return Mojo::Promise->all($query_p, $locale_p)
      ->then(sub {
        my $res = shift;
        my $locale = shift;

        # Create temporary file
        my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.xlsx');

        # Spreadsheet
        my $workbook = Excel::Writer::XLSX->new($fh->filename);
        $workbook->set_optimization();

        # Formats
        my $header_format = $workbook->add_format();
        $header_format->set_bold();

        # Worksheet
        my $worksheet = $workbook->add_worksheet($year);

        # Headers
        my @headers = (
            qw(LOCALIDADE TEMA INDICADOR), 'MÉDIA RELATIVA', 'MÉDIA ABSOLUTA', qw(DESAGREGADOR CLASSIFICAÇÃO),
            'VALOR RELATIVO', 'VALOR ABSOLUTO', 'FONTE',
        );

        for (my $i = 0; $i < scalar @headers; $i++) {
            $worksheet->write(0, $i, $headers[$i], $header_format);
        }

        # Write data
        my $line = 1;
        while (my $r = $res->[0]->hash) {
            # Write lines
            my @keys = qw(
                locale_name area_name indicator_description average_relative average_absolute
                subindicator_description subindicator_classification subindicator_value_relative
                subindicator_value_absolute base
            );
            for (my $i = 0; $i < scalar @keys; $i++) {
                $worksheet->write($line, $i, $r->{$keys[$i]});
            }
            $line++;
        }

        # Add timestamp
        my $footer_format = $workbook->add_format();
        $footer_format->set_italic();
        $footer_format->set_size(9);

        $line += 5;
        $worksheet->write($line++, 0, 'Dados extraídos pela plataforma Observa', $footer_format);
        my $now = $self->app->model('DateTime')->now();
        $worksheet->write(
            $line++,
            0,
            sprintf(
                "%02d/%02d/%02d às %02d:%02d horário de Brasília.",
                $now->day, $now->month, $now->year,
                $now->hour, $now->minute,
            ),
            $footer_format,
        );

        close $fh;
        return $fh, $locale->[0]->hash->{name};
    });
}

sub get_historical {
    my ($self, %opts) = @_;

    my $area_id   = $opts{area_id};
    my $locale_id = $opts{locale_id};
    my @binds     = ((($area_id) x 2), $locale_id);

    return $self->app->pg->db->query(<<"SQL_QUERY", @binds);
      SELECT
        locale.id,
        CASE
          WHEN locale.type = 'city' THEN CONCAT(locale.name, ', ', state.uf)
          ELSE locale.name
        END AS name,
        locale.type,
        locale.latitude,
        locale.longitude,
        COALESCE(
          (
            SELECT JSON_AGG("all".result)
            FROM (
              SELECT ROW_TO_JSON("row") result
              FROM (
                SELECT
                  indicator.id,
                  indicator.description,
                  indicator.base,
                  indicator.concept,
                  ROW_TO_JSON(area.*) AS area,
                  (
                    SELECT ARRAY_AGG(indicator_values)
                    FROM (
                      SELECT
                        indicator_locale.year           AS year,
                        indicator_locale.value_relative AS value_relative,
                        indicator_locale.value_absolute AS value_absolute
                      FROM indicator_locale
                        WHERE indicator_locale.indicator_id = indicator.id
                          AND indicator_locale.locale_id = locale.id
                          AND (
                            indicator_locale.value_absolute IS NOT NULL
                            OR indicator_locale.value_relative IS NOT NULL
                          )
                      ORDER BY indicator_locale.year DESC, indicator_locale.indicator_id ASC
                    ) indicator_values
                  ) AS values,
                  COALESCE(
                    (
                      SELECT ARRAY_AGG(subindicators)
                      FROM (
                        SELECT
                          DISTINCT ON (classification) subindicator.classification AS classification,
                          COALESCE(
                            (
                              SELECT ARRAY_AGG(sx)
                              FROM (
                                SELECT
                                  s2.id,
                                  s2.description,
                                  (
                                    SELECT ARRAY_AGG(sl)
                                    FROM (
                                      SELECT
                                        subindicator_locale.year,
                                        subindicator_locale.value_relative,
                                        subindicator_locale.value_absolute
                                      FROM subindicator_locale
                                      WHERE subindicator_locale.indicator_id = indicator.id
                                        AND subindicator.classification = s2.classification
                                        AND subindicator_locale.subindicator_id = s2.id
                                        AND subindicator_locale.locale_id = locale.id
                                        AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                      ORDER BY subindicator_locale.year DESC, subindicator_locale.subindicator_id ASC
                                    ) sl
                                  ) AS values
                                FROM subindicator s2
                                WHERE subindicator.classification = s2.classification
                                  AND EXISTS (
                                    SELECT 1 FROM subindicator_locale
                                    WHERE subindicator_locale.subindicator_id = s2.id
                                      AND subindicator_locale.locale_id = locale.id
                                      AND subindicator_locale.indicator_id = indicator.id
                                      AND (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                  )
                              ) sx
                            ),
                            ARRAY[]::record[]
                          ) AS data
                        FROM subindicator
                        WHERE EXISTS (
                          SELECT 1
                          FROM subindicator_locale
                          WHERE subindicator_locale.subindicator_id = subindicator.id
                            AND subindicator_locale.indicator_id = indicator.id
                            AND subindicator_locale.locale_id = locale.id
                            AND (
                              subindicator_locale.value_relative IS NOT NULL
                              OR subindicator_locale.value_absolute IS NOT NULL
                            )
                        )
                      ) AS subindicators
                    ),
                    ARRAY[]::record[]
                  ) AS subindicators
                FROM indicator
                JOIN area
                  ON area.id = indicator.area_id
                WHERE (?::text IS NULL OR area.id = ?::int)
                  AND EXISTS (
                    SELECT 1
                    FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id = locale.id
                  )
                ORDER BY indicator.id
              ) AS "row"
            ) "all"
          ),
          '[]'::json
        ) AS indicators
      FROM locale
      LEFT JOIN city
        ON locale.type = 'city' AND locale.id = city.id
      LEFT JOIN state
        ON locale.type = 'city' AND city.state_id = state.id
      WHERE locale.id = ?
      GROUP BY 1,2,3
SQL_QUERY
}

sub get_random_indicator {
    my ($self, %args) = @_;

    my $locale_id_ne = $args{locale_id_ne};

    my $db = $self->app->pg->db;

    # Get some random locale which contains data
    my $cond_locale = '';
    $cond_locale = "WHERE locale_id NOT IN(@{[join ',', map '?', @{ $locale_id_ne }]})\n"
      if defined $locale_id_ne && scalar @{$locale_id_ne} > 0;

    my $random = $db->query(<<"SQL_QUERY", @{ $locale_id_ne || [] });
      SELECT
        locale_id,
        ARRAY[random_pick(area_a1), random_pick(area_a2), random_pick(area_a3)] AS indicators
      FROM random_locale_indicator
      $cond_locale
      ORDER BY RANDOM()
      LIMIT 1
SQL_QUERY

    # Get data
    my ($locale_id, $indicator_ids) = @{ $random->array };

    return $db->query(<<"SQL_QUERY", @{ $indicator_ids }, $locale_id);
      WITH max_year AS (
        SELECT MAX(year.max) AS year
        FROM (
          SELECT MAX(year)
          FROM indicator_locale
          UNION SELECT MAX(year)
          FROM subindicator_locale
        ) year
      )
      SELECT
        locale.id,
        CASE
          WHEN locale.type = 'city' THEN CONCAT(locale.name, ', ', state.uf)
          ELSE locale.name
        END AS name,
        locale.type,
        locale.latitude,
        locale.longitude,
        (
          SELECT JSON_AGG("all".result)
          FROM (
            SELECT ROW_TO_JSON("row") result
            FROM (
              SELECT
                indicator.id,
                indicator.description,
                indicator.base,
                indicator.concept,
                ROW_TO_JSON(area.*) AS area,
                (
                  SELECT JSON_BUILD_OBJECT(
                    'year', indicator_locale.year,
                    'value_relative', indicator_locale.value_relative,
                    'value_absolute', indicator_locale.value_absolute
                  )
                  FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id    = locale.id
                      AND indicator_locale.year         = ( SELECT year FROM max_year )
                  ORDER BY indicator_locale.year DESC
                  LIMIT 1
                ) AS values
              FROM indicator
              JOIN area
                ON area.id = indicator.area_id
              JOIN indicator_locale
                ON indicator.id = indicator_locale.indicator_id
                  AND indicator_locale.locale_id = locale.id
              WHERE indicator.id IN (@{[join ',', map '?', @{ $indicator_ids }]})
                AND indicator_locale.year = ( SELECT year FROM max_year )
              ORDER BY indicator.id
            ) AS "row"
          ) AS "all"
        ) AS indicators
      FROM locale
      LEFT JOIN city
        ON locale.type = 'city' AND locale.id = city.id
      LEFT JOIN state
        ON locale.type = 'city' AND city.state_id = state.id
      WHERE locale.id IN(0, ?)
      ORDER BY locale.id
SQL_QUERY
}

1;
