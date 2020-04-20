use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Compare two locales' => sub {

    # At this development state, I do not have any data about states, regions or country. As I can't compare two
    # cities, I will update data from some random locale just for test this feature.
    eval {
        my $tx = $pg->db->begin();

        my $city_id = 2803609;
        my $state_id = 28;
#         $pg->db->query(<<'SQL_QUERY', $state_id, $city_id);
#           UPDATE indicator_locale
#             SET locale_id = ?
#           WHERE locale_id IN (
#             SELECT DISTINCT(locale_id)
#             FROM indicator_locale
#             WHERE locale_id <> ?
#             LIMIT 1
#           )
# SQL_QUERY

#         $pg->db->query(<<'SQL_QUERY', $state_id, $city_id);
#           UPDATE subindicator_locale
#             SET locale_id = ?
#           WHERE locale_id IN (
#             SELECT DISTINCT(locale_id)
#             FROM subindicator_locale
#             WHERE locale_id <> ?
#             LIMIT 1
#           )
# SQL_QUERY

        $t->get_ok("/v1/data/compare", form => { locale_id => $city_id })
          ->status_is(200)
          ->json_has('/comparison/0/id')
          ->json_has('/comparison/0/name')
          ->json_has('/comparison/0/type')
          ->json_has('/comparison/0/indicators')
          #->json_has('/comparison/0/indicators/0/id')
          #->json_has('/comparison/0/indicators/0/base')
          #->json_has('/comparison/0/indicators/0/description')
          #->json_has('/comparison/0/indicators/0/values/0/year')
          #->json_has('/comparison/0/indicators/0/values/0/value_relative')
          #->json_has('/comparison/0/indicators/0/values/0/value_absolute')
          ->json_has('/comparison/1/id')
          ->json_has('/comparison/1/name')
          ->json_has('/comparison/1/type')
          ->json_has('/comparison/1/indicators');
          #->json_has('/comparison/1/indicators/0/id')
          #->json_has('/comparison/1/indicators/0/base')
          #->json_has('/comparison/1/indicators/0/description')
          #->json_has('/comparison/1/indicators/0/values/0/year')
          #->json_has('/comparison/1/indicators/0/values/0/value_relative')
          #->json_has('/comparison/1/indicators/0/values/0/value_absolute');

        # Rollback
        undef $tx;
    };
    is $@, '';
};


done_testing();
