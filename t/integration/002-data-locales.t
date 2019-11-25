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

    $t->get_ok("/v1/locales/foobar")
      ->status_is(400)
      ->json_has('/errors')
      ->json_is('/errors/0/message', 'Expected integer - got string.')
      ->json_is('/errors/0/path', '/locale_id');

    $t->get_ok("/v1/locales/$locale_id")
      ->status_is(200)
      ->json_has('/locale/id')
      ->json_has('/locale/name')
      ->json_has('/locale/type')
      ->json_has('/locale/indicators')
      ->json_has('/locale/indicators/0/id')
      ->json_has('/locale/indicators/0/base')
      ->json_has('/locale/indicators/0/description')
      ->json_has('/locale/indicators/0/values/0/year')
      ->json_has('/locale/indicators/0/values/0/value_relative')
      ->json_has('/locale/indicators/0/values/0/value_absolute');
    #p $t->tx->res->json;
};

subtest_buffered 'Filter by area_id' => sub {

    $t->get_ok("/v1/locales/$locale_id", form => { area_id => 'foobar' } )
      ->status_is(400)
      ->json_has('/errors')
      ->json_is('/errors/0/message', 'Expected integer - got string.')
      ->json_is('/errors/0/path', '/area_id');

    my $area_id = 2;
    $t->get_ok("/v1/locales/$locale_id", form => { area_id => $area_id } )
      ->status_is(200);

    ok my $indicators = $t->tx->res->json->{locale}->{indicators};
    is scalar(map { $_->{area}->{id} } @{$indicators}),
       scalar(grep { $_->{area}->{id} == 2 } @{$indicators}),
       'all items is of area_id=2';
    p $t->tx->res->json;
};

done_testing();
