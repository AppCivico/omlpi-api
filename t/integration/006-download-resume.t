use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

my $locale_id = 2803609;

$t->get_ok("/v1/data/download_resume", form => { locale_id => $locale_id })
  ->status_is(200);

my $headers = $t->tx->res->content->headers;
like $headers->header('content-disposition'), qr{^attachment;filename="};

done_testing();
