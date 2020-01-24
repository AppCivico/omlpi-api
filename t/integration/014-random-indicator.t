use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Get random indicator' => sub {

    # At this development state, I do not have data about Brazil
    # So I will update data from some random locale
    eval {
        my $tx = $pg->db->begin();

        $pg->db->query(<<'SQL_QUERY');
          UPDATE indicator_locale
            SET locale_id = 1
          WHERE locale_id = (
            SELECT locale_id
            FROM indicator_locale
            LIMIT 1
          )
SQL_QUERY

        $t->get_ok("/v1/data/random_indicator")
          ->status_is(200);
        p $t->tx->res->json;

        undef $tx;
    };
};

done_testing();
