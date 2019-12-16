use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

my $locale_id = 2803609;

$t->get_ok("/v1/data/download_indicator", form => { locale_id => $locale_id })
  ->status_is(200);

p $t->tx->res->json;
my $headers = $t->tx->res->content->headers;
p $headers;
#like $headers->header('content-disposition'), qr{^attachment;filename="};

done_testing();
