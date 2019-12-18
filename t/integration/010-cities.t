use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

$t->get_ok("/v1/cities")
  ->status_is(200)
  ->json_has('/cities/0/id')
  ->json_has('/cities/0/latitude')
  ->json_has('/cities/0/longitude');

is scalar @{$t->tx->res->json->{cities}}, 5568;

done_testing();
