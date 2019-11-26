package Andi::Model::Locale;
use Mojo::Base 'MojoX::Model';

sub list {
    my $self = shift;

    return $self->app->pg->db->query_p(<<'SQL_QUERY');
      SELECT
        l.id,
        CASE
          WHEN l.type = 'city' THEN CONCAT(l.name, ', ', s.uf)
          ELSE l.name
        END AS name,
        l.type
      FROM locale l
      LEFT JOIN city ct
        ON l.type = 'city' AND l.id = ct.id
      LEFT JOIN state s
        ON l.type = 'city' AND ct.state_id = s.id
      ORDER BY (
        CASE l.type
          WHEN 'country' THEN 1
          WHEN 'region'  THEN 2
          WHEN 'state'   THEN 3
          WHEN 'city'    THEN 4
        END
      )
SQL_QUERY
}

sub get {
    my ($self, %opts) = @_;

    my @binds = ();

    # Filter by area_id
    my $cond_area_id = '';
    if (defined $opts{area_id}) {
        $cond_area_id = "WHERE area.id = ?";
        push @binds, $opts{area_id};
    }
    push @binds, $opts{locale_id};

    return $self->app->pg->db->query_p(<<"SQL_QUERY", @binds);
      SELECT
        locale.id   AS id,
        locale.name AS name,
        locale.type AS type,
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
                      WHERE indicator_locale.locale_id = locale.id
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
                                  WHERE (subindicator_locale.value_relative IS NOT NULL OR subindicator_locale.value_absolute IS NOT NULL)
                                    AND subindicator_locale.indicator_id = indicator.id
                                    AND subindicator_locale.subindicator_id = s2.id
                                    AND subindicator_locale.locale_id = locale.id
                                  ORDER BY subindicator_locale.year DESC
                                ) sl
                              ) AS values
                            FROM subindicator s2
                            WHERE subindicator.classification = s2.classification
                          ) sx
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
              $cond_area_id
              ORDER BY indicator.id
            ) AS "row"
          ) "all"
        ) AS indicators
      FROM locale
      WHERE locale.id = ?
      GROUP BY 1,2,3
SQL_QUERY
}

1;
