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
#my $locale_id = 3550704;
my $locale_id = 2803609;

subtest_buffered 'Filter by locale' => sub {

    $t->get_ok("/locales/foobar")
      ->status_is(400)
      ->json_has('/errors')
      ->json_is('/errors/0/message', 'Expected integer - got string.')
      ->json_is('/errors/0/path', '/localeId');

    $t->get_ok("/locales/$locale_id")
      ->status_is(200)
      ->json_has('/locale/id')
      ->json_has('/locale/name')
      ->json_has('/locale/type')
      ->json_has('/locale/indicators')
      ->json_has('/locale/indicators/0/area')
      ->json_has('/locale/indicators/0/base')
      ->json_has('/locale/indicators/0/description')
      ->json_has('/locale/indicators/0/value_absolute')
      ->json_has('/locale/indicators/0/value_relative');
    #p $t->tx->res->json;
};

done_testing();
