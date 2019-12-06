package Andi::Model::Data;
use Mojo::Base 'MojoX::Model';

use Text::CSV;
use Excel::Writer::XLSX;
use File::Temp qw(tempfile);
use Mojo::Util qw(decode);
use Andi::Utils qw(mojo_home);
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
                      ORDER BY indicator_locale.year
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
                        --GROUP BY subindicator.classification
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
      WHERE locale.id = ?
      GROUP BY 1,2,3
SQL_QUERY
}

sub compare {
    my ($self, %opts) = @_;

    my $year       = $opts{year};
    my $area_id    = $opts{area_id};
    my @locale_ids = @{$opts{locale_id}};
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
    my $template = $home->rel_file('resources/template_resume.html')->to_abs;
    my $mt = Mojo::Template->new(vars => 1);

    # Fix encoding issues
    my $slurp = decode('UTF-8', $template->slurp);

    # Create temporary file
    my $fh = File::Temp->new(UNLINK => 1, SUFFIX => '.html');
    binmode $fh, ':utf8';

    # Write to file
    print $fh $mt->render($slurp, {
        locale_name => $data->{name},
        indicators  => $data->{indicators},
    });
    close $fh;

    # Generate another temporary file
    my (undef, $pdf_file) = tempfile(SUFFIX => '.pdf');
    run ['wkhtmltopdf', $fh->filename, $pdf_file];

    return $pdf_file;
}

sub get_all_data {
    my $self = shift;

    my $query = $self->app->pg->db->query_p(<<'SQL_QUERY');
      SELECT
        locale.id             AS locale_id,
        locale.name           AS locale_name,
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
      INNER JOIN LATERAL (
        SELECT
          indicator.id AS indicator_id,
          subindicator.description AS subindicator_description,
          subindicator.id AS subindicator_id,
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
          NULL AS subindicator_value_absolute,
          NULL AS subindicator_value_relative,
          NULL AS subindicator_year
      ) s ON s.indicator_id = indicator.id
      ORDER BY locale.name, indicator.id, indicator_locale.year DESC, (s.subindicator_id IS NULL) DESC, s.subindicator_year
SQL_QUERY

    return $query->then(sub {
        my $res = shift;

        # Create temporary file
        my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.xlsx', DIR => "/home/junior/projects/omlpi-api/tmp");
        #binmode $fh, ':utf8';

        # Spreadsheet
        my $workbook = Excel::Writer::XLSX->new($fh->filename);
        $workbook->set_optimization();

        # Write data
        my %worksheets  = ();
        my %has_headers = ();
        while (my $r = $res->hash) {
            # Get or create worksheet
            my $year = $r->{indicator_value_year};
            my $worksheet = $worksheets{$year};
            if (!defined($worksheet)) {
                $worksheets{$year} = $worksheet = $workbook->add_worksheet($year);
            }

            # Write headers if hasn't
            if (!$has_headers{$year}++) {
                # TODO Bold
                p [ 'year', $year];
                my @headers = (
                    qw(LOCALIDADE TEMA INDICADOR), 'VALOR RELATIVO', 'VALOR ABSOLUTO', qw(DESAGREGADOR CLASSIFICAÇÃO),
                    'VALOR RELATIVO', 'VALOR ABSOLUTO',
                );
                for (my $i = 0; $i < scalar @headers; $i++) {
                    $worksheet->write(0, $i, $headers[$i]);
                }
            }
        }

        close $fh;
    });

}

1;
