use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Compare two locales' => sub {

    my @locale_ids = (2803609, 3301900);
    $t->get_ok("/v1/locales/compare", form => { locale_id => \@locale_ids })
      ->status_is(200);
    p $t->tx->res->json;
};


done_testing();
