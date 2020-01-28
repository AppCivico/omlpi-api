use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Get random indicator' => sub {

    # Mock data for testing purposes
    eval {
        my $tx = $pg->db->begin();

        my $year = $t->app->model('Data')->get_max_year()->array->[0];

        $pg->db->query(<<'SQL_QUERY', $year);
          INSERT INTO indicator_locale (indicator_id, locale_id, year, value_relative, value_absolute)
          SELECT
            id                            AS indicator_id,
            1                             AS locale_id,
            ?                             AS year,
            RANDOM() * (100 + 1)          AS value_relative,
            FLOOR(random() * (10000 + 1)) AS value_relative
          FROM indicator
SQL_QUERY

        # Test endpoint
        $t->get_ok("/v1/data/random_indicator")
          ->status_is(200)
          ->json_is('/locales/0/name', 'Brasil')
          ->json_has('/locales/0/indicator/area/name')
          ->json_has('/locales/0/indicator/description')
          ->json_has('/locales/0/indicator/values/year')
          ->json_has('/locales/0/indicator/values/value_absolute')
          ->json_has('/locales/0/indicator/values/value_relative')
          ->json_has('/locales/1/name')
          ->json_has('/locales/1/indicator/area/name')
          ->json_has('/locales/1/indicator/description')
          ->json_has('/locales/1/indicator/values/year')
          ->json_has('/locales/1/indicator/values/value_absolute')
          ->json_has('/locales/1/indicator/values/value_relative');

        # Rollback
        undef $tx;
    };
    is $@, '';
};

done_testing();
