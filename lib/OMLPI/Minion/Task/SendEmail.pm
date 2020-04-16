package OMLPI::Minion::Task::SendEmail;
use Mojo::Base 'Mojolicious::Plugin';

use OMLPI::TrapSignals;
use OMLPI::Minion::Task::SendEmail::Mailer;

sub register {
    my ($self, $app) = @_;

    $app->minion->add_task(send_email => \&do);
}

sub do {
    my ($job, $email, $bcc) = @_;

    my $pg = $job->app->pg;

    state $mailer = OMLPI::Minion::Task::SendEmail::Mailer->new(
        smtp_server   => $ENV{SMTP_SERVER},
        smtp_port     => $ENV{SMTP_PORT},
        smtp_username => $ENV{SMTP_USERNAME},
        smtp_password => $ENV{SMTP_PASSWORD},
    );

    my $log = $job->app->log;
    $log->info('Sending email...');
    if ($mailer->send($email, $bcc)) {
        $log->info('Email sent!');
        return $job->finish(1);
    }

    $log->error('Cant send email!');
    return $job->fail();
}

1;
