package Andi::Minion::Task::SendEmail;
use Mojo::Base 'Mojolicious::Plugin';

use DDP;
use Andi::TrapSignals;

sub register {
    my ($self, $app) = @_;

    $app->minion->add_task(send_email => \&do);
}

sub do {
    my ($job, $email) = @_;

    my $pg = $job->app->pg;

    p $email;

    return $job->finish(1);
}

1;
