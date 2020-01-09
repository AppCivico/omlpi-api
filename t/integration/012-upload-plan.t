use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use OMLPI::Test;

my $t = test_instance();
my $pg = $t->app->pg;
my $db = $pg->db;

eval {
    $db->query('truncate minion_jobs restart identity');
    $db->query('truncate minion_locks restart identity');
    $db->query('truncate minion_workers restart identity');
};
ok $@ eq '' || $@ =~ m{relation "minion_(jobs|locks|workers)" does not exist at};

subtest_buffered 'UploadPlan | post' => sub {

    my $city = $pg->db->select('city', ['id'], undef, { limit => 1 } )->hash;

    $t->post_ok("/v1/upload_plan", form => {
        name      => 'Junior M',
        locale_id => $city->{id},
        email     => 'carlos@appcivico.com',
        file      => { file => "$RealBin/../data/logo.pdf" },
      })
      ->status_is(200);

    ok $t->app->minion->perform_jobs();
    my $stats = $t->app->minion->stats;
    is $stats->{failed_jobs},   0, 'failed_jobs=0';
    is $stats->{finished_jobs}, 1, 'finished_jobs=1';
};


done_testing();
