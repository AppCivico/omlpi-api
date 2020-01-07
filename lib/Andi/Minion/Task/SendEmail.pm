package Andi::Minion::Task::SendEmail;
use Mojo::Base 'Mojolicious::Plugin';

use Andi::TrapSignals;

sub register {
    my ($self, $app) = @_;

    $app->minion->add_task(send_email => \&do);
}

sub do {
    my ($job) = @_;

    my $pg = $job->app->pg;

    return $job->finish(1);
}

1;
