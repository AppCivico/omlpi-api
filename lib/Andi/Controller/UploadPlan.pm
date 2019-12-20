package Andi::Controller::UploadPlan;
use Mojo::Base 'Andi::Controller';

use DDP;

sub post {
    my $c = shift;

    $c->openapi->valid_input() or return;
}

1;
