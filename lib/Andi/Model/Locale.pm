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
    my ($self, $locale_id) = @_;

    return $self->app->pg->db->query_p(<<'SQL_QUERY', $locale_id);
      SELECT
        locale.id   AS id,
        locale.name AS name,
        locale.type AS type,
        (
          SELECT JSON_AGG( xx.indloca )
          FROM (
            SELECT ROW_TO_JSON(valores) indloca
            FROM (
              SELECT
                indicator.description,
                indicator_locale.value_relative,
                indicator_locale.value_absolute,
                indicator.base,
                ROW_TO_JSON(area.*) AS area
              FROM indicator_locale
              JOIN indicator
                ON indicator.id = indicator_locale.id
              JOIN area
                ON area.id = indicator.area_id
              WHERE indicator_locale.locale_id = locale.id
              ORDER BY indicator_locale.locale_id
            ) AS valores
          ) xx
        ) AS indicators
      FROM locale
      WHERE locale.id = ?
      GROUP BY 1,2,3
SQL_QUERY
}

1;
