use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Andi::Test;

my $t = test_instance();
my $pg = $t->app->pg;

subtest_buffered 'UploadPlan | post' => sub {

    $t->post_ok("/v1/upload_plan", form => { })
      ->status_is(200);
};

done_testing();
