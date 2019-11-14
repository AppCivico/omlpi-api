use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

#ok my $locale = $pg->db
#  ->select("locale", ['id'], { name => 'Iguape' } )
#  ->hash;
#ok my $locale_id = $locale->{id};
my $locale_id = 3550704;

$t->get_ok("/locales/$locale_id")
  ->status_is(200);
p $t->tx->res->json;

done_testing();
