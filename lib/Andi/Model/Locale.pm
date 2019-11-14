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
      select
        locale.id                       AS id,
        locale.name                     AS name,
        locale.type                     AS type,
        json_agg(
            json_build_object(
                'id',          indicator.id,
                'description', indicator.description
            )
        ) as indicators
      from locale
      left join indicator_locale
        on locale.id = indicator_locale.locale_id
      join indicator
        on indicator.id = indicator_locale.indicator_id
      left join subindicator_locale
        on locale.id = subindicator_locale.locale_id and subindicator_locale.indicator_id = indicator.id
      join subindicator
        on subindicator.id = subindicator_locale.subindicator_id
      where locale.id = ?
      group by locale.id
SQL_QUERY

    #return $self->app->pg->db->select_p(
    #    [
    #        "locale",
    #        ['-left' => 'indicator_locale', 'indicator_locale.locale_id' => 'locale.id' ],
    #        ['-left' => 'subindicator_locale', 'subindicator_locale.indicator_id' => 'indicator_locale.indicator_id' ]
    #    ],
    #    ['*'],
    #    { 'locale.id' => $locale_id }
    #);
}

1;
