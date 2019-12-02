use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

my $locale_id = 2803609;

subtest_buffered 'Filter by locale' => sub {

    $t->get_ok("/v1/data?locale_id=$locale_id")
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
};

subtest_buffered 'Filter by area_id' => sub {

    $t->get_ok("/v1/data", form => { locale_id => $locale_id, area_id => 'foobar' } )
      ->status_is(400)
      ->json_has('/errors')
      ->json_is('/errors/0/message', 'Expected integer - got string.')
      ->json_is('/errors/0/path', '/area_id');

    my $area_id = 2;
    $t->get_ok("/v1/data", form => { locale_id => $locale_id, area_id => $area_id } )
      ->status_is(200);

    ok my $indicators = $t->tx->res->json->{locale}->{indicators};
    is scalar(map { $_->{area}->{id} } @{$indicators}),
       scalar(grep { $_->{area}->{id} == 2 } @{$indicators}),
       'all items is of area_id=2';
};

subtest_buffered 'Filter by year' => sub {

    $t->get_ok("/v1/data", form => { locale_id => $locale_id, year => 2014 } )
      ->status_is(400)
      ->json_is('/errors/0/path', '/year');

    my $year = 2018;
    $t->get_ok("/v1/data", form => { locale_id => $locale_id, year => $year } )
      ->status_is(200);

    ok my $indicators = $t->tx->res->json->{locale}->{indicators};
    is scalar(map { map { $_->{year} } @{ $_->{values} } } @{$indicators}),
       scalar(grep { $_ == $year } map { map { $_->{year} } @{ $_->{values} } } @{$indicators}),
       'all data of specified year';
};

done_testing();
