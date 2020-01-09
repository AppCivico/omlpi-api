package OMLPI::Controller::UploadPlan;
use Mojo::Base 'OMLPI::Controller';

use File::Temp;
use Mojo::Util qw(decode);
use OMLPI::Utils qw(mojo_home);
use OMLPI::Minion::Task::SendEmail::Mailer::Template;

use DDP;

sub post {
    my $c = shift;

    $c->openapi->valid_input() or return;

    # File upload
    my $upload = $c->param('file');
    my $fh = File::Temp->new(UNLINK => 1);
    $upload->move_to($fh);

    my $city = $c->model('City')->get_name_with_uf($c->param('city_id'))->hash->{name};

    # Get template
    my $home = mojo_home();
    my $template = $home->rel_file('resources/plan/template.tt')->to_abs;

    # Fix encoding issues
    my $slurp = decode('UTF-8', $template->slurp);

    my $email = OMLPI::Minion::Task::SendEmail::Mailer::Template->new(
        to       => 'carlos@appcivico.com',
        from     => 'no-reply@appcivico.com',
        subject  => 'Upload de plano',
        template => $slurp,
        vars     => {
            name  => $c->param('name'),
            email => $c->param('email'),
            city  => $city,
        },
        attachments => [
            {
                fh   => $fh,
                name => $upload->filename,
            }
        ]
    )->build_email();

    $c->minion->enqueue(send_email => [ $email->as_string() ]);

    close $fh;

    return $c->render(json => {}, status => 200);
}

1;
