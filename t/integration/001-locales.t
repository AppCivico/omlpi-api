use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();

$t->get_ok("/v1/locales")
  ->status_is(200)
  ->json_has('/locales')
  ->json_has('/locales/0/id')
  ->json_has('/locales/0/name');

done_testing();
