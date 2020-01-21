use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Get historical series' => sub {

    my $locale_id = 2803609;
    $t->get_ok("/v1/data/historical", form => { locale_id => $locale_id })
      ->json_has('/historical')
      ->status_is(200);
    p $t->tx->res->json;
};

done_testing();
