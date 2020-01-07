use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'UploadPlan | post' => sub {

    my $city = $pg->db->select('city', ['id'], undef, { limit => 1 } )->hash;

    $t->post_ok("/v1/upload_plan", form => {
        name    => 'Junior M',
        city_id => $city->{id},
        email   => 'carlos@appcivico.com',
        file    => { file => "$RealBin/../data/logo.pdf" },
      })
      ->status_is(200);

    p $t->tx->res->json;

    ok $t->app->minion->perform_jobs();
};

done_testing();
