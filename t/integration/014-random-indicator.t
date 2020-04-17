use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

plan skip_all => 'skip for a while';

my $t = test_instance();
my $db = $t->app->pg->db;

subtest_buffered 'Get random indicator' => sub {

    # Mock data for testing purposes
    my $locale_id = 3520301;
    ok $db->query(<<'SQL_QUERY', $locale_id);
      WITH max_year AS (
        SELECT MAX(year.max) AS year
        FROM (
          SELECT MAX(year) FROM indicator_locale
          UNION
          SELECT MAX(year) FROM subindicator_locale
        ) year
      )
      INSERT INTO indicator_locale (indicator_id, locale_id, year, value_relative, value_absolute)
      SELECT
        id                            AS indicator_id,
        1                             AS locale_id,
        ( SELECT year FROM max_year ) AS year,
        RANDOM() * (100 + 1)          AS value_relative,
        FLOOR(random() * (10000 + 1)) AS value_relative
      FROM indicator
      UNION
      SELECT
        id                            AS indicator_id,
        ?::int                        AS locale_id,
        ( SELECT year FROM max_year ) AS year,
        RANDOM() * (100 + 1)          AS value_relative,
        FLOOR(random() * (10000 + 1)) AS value_relative
      FROM indicator
      ON CONFLICT DO NOTHING
SQL_QUERY

    ok $db->query("REFRESH MATERIALIZED VIEW random_locale_indicator"), 'refresh materialized view';

    # Test endpoint
    $t->get_ok("/v1/data/random_indicator")
      ->status_is(200)
      ->json_is('/locales/0/name', 'Brasil')
      ->json_has('/locales/0/indicators/0/area/name')
      ->json_has('/locales/0/indicators/0/description')
      ->json_has('/locales/0/indicators/0/values/year')
      ->json_has('/locales/0/indicators/0/values/value_absolute')
      ->json_has('/locales/0/indicators/0/values/value_relative')
      ->json_has('/locales/0/indicators/1/area/name')
      ->json_has('/locales/0/indicators/1/description')
      ->json_has('/locales/0/indicators/1/values/year')
      ->json_has('/locales/0/indicators/1/values/value_absolute')
      ->json_has('/locales/0/indicators/1/values/value_relative')
      ->json_has('/locales/0/indicators/2/area/name')
      ->json_has('/locales/0/indicators/2/description')
      ->json_has('/locales/0/indicators/2/values/year')
      ->json_has('/locales/0/indicators/2/values/value_absolute')
      ->json_has('/locales/0/indicators/2/values/value_relative')
      ->json_is('/locales/0/indicators/3', undef)
      ->json_has('/locales/1/name')
      ->json_has('/locales/1/indicators/0/area/name')
      ->json_has('/locales/1/indicators/0/description')
      ->json_has('/locales/1/indicators/0/values/year')
      ->json_has('/locales/1/indicators/0/values/value_absolute')
      ->json_has('/locales/1/indicators/0/values/value_relative')
      ->json_has('/locales/1/indicators/1/area/name')
      ->json_has('/locales/1/indicators/1/description')
      ->json_has('/locales/1/indicators/1/values/year')
      ->json_has('/locales/1/indicators/1/values/value_absolute')
      ->json_has('/locales/1/indicators/1/values/value_relative')
      ->json_has('/locales/1/indicators/2/area/name')
      ->json_has('/locales/1/indicators/2/description')
      ->json_has('/locales/1/indicators/2/values/year')
      ->json_has('/locales/1/indicators/2/values/value_absolute')
      ->json_has('/locales/1/indicators/2/values/value_relative')
      ->json_is('/locales/1/indicators/3', undef);
};

done_testing();