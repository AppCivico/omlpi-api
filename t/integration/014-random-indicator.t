use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Get random indicator' => sub {

    # At this development state, I do not have data about Brazil. So I will mock data for testing purposes
    eval {
        my $tx = $pg->db->begin();

        $pg->db->query(<<'SQL_QUERY');
          INSERT INTO indicator_locale (indicator_id, locale_id, year, value_relative, value_absolute)
          SELECT
            id                            AS indicator_id,
            1                             AS locale_id,
            2019                          AS year,
            RANDOM() * (100 + 1)          AS value_relative,
            FLOOR(random() * (10000 + 1)) AS value_relative
          FROM indicator
SQL_QUERY

        $t->get_ok("/v1/data/random_indicator")
          ->status_is(200);
        p $t->tx->res->json;

        #$tx->commit();
        undef $tx;
    };
    is $@, '';
};

done_testing();
