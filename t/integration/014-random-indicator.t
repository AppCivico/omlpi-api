use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Get random indicator' => sub {

    $t->get_ok("/v1/data/random_indicator")
      ->status_is(200);
    p $t->tx->res->json;
};

done_testing();
