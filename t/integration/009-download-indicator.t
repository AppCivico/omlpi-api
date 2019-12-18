use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

my $locale_id = 2803609;
my $indicator_id = 1;
$t->get_ok("/v1/data/download_indicator", form => { locale_id => $locale_id, year => 2018, indicator_id => $indicator_id })
  ->status_is(200);

my $headers = $t->tx->res->content->headers;
like $headers->header('content-disposition'), qr{^attachment;filename="};

done_testing();