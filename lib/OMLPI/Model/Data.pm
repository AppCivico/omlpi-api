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
    my @binds     = ((($year) x 8), (($area_id) x 2), (($year) x 2), $locale_id);

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
                      ORDER BY indicator_locale.year DESC
                      LIMIT 1
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
                                    SELECT ROW_TO_JSON(sl)
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
                                        AND (?::int IS NULL OR subindicator_locale.year = ?::int)
                                      ORDER BY subindicator_locale.year DESC
                                      LIMIT 1
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
                JOIN indicator_locale
                  ON indicator.id = indicator_locale.indicator_id
                    AND indicator_locale.locale_id = locale.id
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
                      ORDER BY indicator_locale.year
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
                JOIN indicator_locale
                  ON indicator.id = indicator_locale.indicator_id
                    AND indicator_locale.locale_id = locale.id
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
    my $self = shift;

    return $self->app->pg->db->query(<<"SQL_QUERY");
      SELECT MAX(years.max) AS year
      FROM (
        SELECT MAX(year)
        FROM indicator_locale
        UNION SELECT MAX(year)
        FROM subindicator_locale
      ) years
SQL_QUERY
}

sub get_resume {
    my ($self, %opts) = @_;

    # Get data
    my $data = $self->get(%opts)->expand->hash;

    # Get template
    my $home = mojo_home();
    my $template = $home->rel_file('resources/resume/index.html')->to_abs;
    my $mt = Mojo::Template->new(vars => 1);

    # Fix encoding issues
    my $slurp = decode('UTF-8', $template->slurp);

    # Create temporary directory
    my $dir = File::Temp->newdir(CLEANUP => 1);
    symlink $home->rel_file("resources/resume/$_"), $dir->dirname . "/$_"
      or die $!
        for qw<css img>;

    # Create temporary file
    my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.html', DIR => $dir->dirname);
    binmode $fh, ':utf8';

    # Write to file
    print $fh $mt->render($slurp, {
        now         => $self->app->model('DateTime')->now(),
        locale_name => $data->{name},
        indicators  => $data->{indicators},
    });
    close $fh;

    # Generate another temporary file
    my (undef, $pdf_file) = tempfile(SUFFIX => '.pdf');
    run ['xvfb-run', 'wkhtmltopdf', '-q', $fh->filename, $pdf_file];

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
        subs.value_absolute              AS subindicator_value_absolute
      FROM indicator
      JOIN indicator_locale
        ON indicator_locale.id = indicator.id
      JOIN area
        ON area.id = indicator.area_id
      JOIN locale
        ON locale.id = indicator_locale.locale_id
      INNER JOIN LATERAL (
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
            'VALOR RELATIVO', 'VALOR ABSOLUTO',
        );

        for (my $i = 0; $i < scalar @headers; $i++) {
            $worksheet->write(0, $i, $headers[$i], $header_format);
        }

        # Write data
        my $line = 1;
        while (my $r = $res->[0]->hash) {
            # Write lines
            my @keys = qw(
                locale_name area_name indicator_description indicator_value_relative indicator_value_absolute
                subindicator_description subindicator_classification subindicator_value_relative
                subindicator_value_absolute
            );
            for (my $i = 0; $i < scalar @keys; $i++) {
                $worksheet->write($line, $i, $r->{$keys[$i]});
            }
            $line++;
        }

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
                          DISTINCT ON (classification) subindicator.classification AS classification,
                          COALESCE(
                            (
                              SELECT ARRAY_AGG(sx)
                              FROM (
                                SELECT
                                  s2.id,
                                  s2.description,
                                  (
                                    SELECT ROW_TO_JSON(sl)
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
                                      ORDER BY subindicator_locale.year DESC
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
                JOIN indicator_locale
                  ON indicator.id = indicator_locale.indicator_id
                    AND indicator_locale.locale_id = locale.id
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
    my $self = shift;

    my $db = $self->app->pg->db;

    my $year = $self->app->model('Data')->get_max_year()->array->[0];

    # Get some random locale which contains data
    my $random = $db->query(<<'SQL_QUERY', $year);
      SELECT locale.id, indicator_locale.indicator_id
      FROM locale
      INNER JOIN indicator_locale
        ON indicator_locale.locale_id = locale.id
      WHERE locale.type = 'city'
        AND indicator_locale.year = ?
      ORDER BY RANDOM()
      LIMIT 1
SQL_QUERY

     my ($locale_id, $indicator_id) = @{ $random->array };

    return $db->query(<<"SQL_QUERY", $year, $indicator_id, $locale_id);
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
                          AND indicator_locale.locale_id    = locale.id
                          AND indicator_locale.year         = ?
                      ORDER BY indicator_locale.year DESC
                    ) indicator_values
                  ) AS values
                FROM indicator
                JOIN area
                  ON area.id = indicator.area_id
                JOIN indicator_locale
                  ON indicator.id = indicator_locale.indicator_id
                    AND indicator_locale.locale_id = locale.id
                WHERE indicator.id = ?
                ORDER BY indicator.id
              ) AS "row"
            ) "all"
          ),
          '[]'::json
        ) AS indicator
      FROM locale
      LEFT JOIN city
        ON locale.type = 'city' AND locale.id = city.id
      LEFT JOIN state
        ON locale.type = 'city' AND city.state_id = state.id
      WHERE locale.id IN(1, ?)
      ORDER BY locale.id
SQL_QUERY
}

1;
