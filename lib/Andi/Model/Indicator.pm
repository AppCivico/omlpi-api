package Andi::Model::Indicator;
use Mojo::Base 'MojoX::Model';

sub list {
    my $self = shift;

    return $self->app->pg->db->query_p(<<'SQL_QUERY');
      SELECT
        indicator.id,
        indicator.description,
        indicator.base,
        ROW_TO_JSON(area.*) AS area
      FROM indicator
      JOIN area
        ON area.id = indicator.id
      ORDER BY indicator.id
SQL_QUERY
}

1;
