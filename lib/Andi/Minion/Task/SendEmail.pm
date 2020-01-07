package Andi::Minion::Task::SendEmail;
use Mojo::Base 'Mojolicious::Plugin';

use DDP;
use Andi::TrapSignals;
use Andi::Minion::Task::SendEmail::Mailer;

sub register {
    my ($self, $app) = @_;

    $app->minion->add_task(send_email => \&do);
}

sub do {
    my ($job, $email) = @_;

    my $pg = $job->app->pg;

    state $mailer = Andi::Minion::Task::SendEmail::Mailer->new(
        smtp_server   => $ENV{SMTP_SERVER},
        smtp_port     => $ENV{SMTP_PORT},
        smtp_username => $ENV{SMTP_USERNAME},
        smtp_password => $ENV{SMTP_PASSWORD},
    );

    if ($mailer->send($email->body, $email->bcc)) {
        return $job->finish(1);
    }
}

1;
