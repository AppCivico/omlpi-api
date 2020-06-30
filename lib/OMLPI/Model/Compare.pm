package OMLPI::Model::Compare;
use Mojo::Base 'MojoX::Model';

use Data::Printer;

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

1;
