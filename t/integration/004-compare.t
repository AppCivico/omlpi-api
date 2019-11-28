use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

plan skip_all => 'Skip this test for a while';

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'Cant compare cities' => sub {

    # Get two random cities
    ok my @locale_ids = map {  $_->[0] }
                        $pg->db->select("locale", [qw(id)], { type => 'city' }, { limit => 2, order_by => \'RANDOM()' } )
                          ->arrays
                          ->each;

    $t->get_ok("/v1/locales/compare", form => { locale_id => \@locale_ids })
      ->status_is(400)
      ->json_is('/errors/0/message', "Can't compare a city with a city.");
};

subtest_buffered 'Compare two locales' => sub {

    my @locale_ids = (2803609, 526);
    $t->get_ok("/v1/locales/compare", form => { locale_id => \@locale_ids })
      ->status_is(200);
    p $t->tx->res->json;
};


done_testing();
