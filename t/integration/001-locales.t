use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();

$t->get_ok("/locales")
  ->status_is(200);
p $t->tx->res->json;

done_testing();
