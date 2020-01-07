package Andi::Controller::UploadPlan;
use Mojo::Base 'Andi::Controller';

use DDP;
use Data::Section::Simple qw(get_data_section);
use Andi::Minion::Task::SendEmail::Mailer::Template;
use File::Temp;

sub post {
    my $c = shift;

    $c->openapi->valid_input() or return;

    # File upload
    my $upload = $c->param('file');
    my $fh = File::Temp->new(UNLINK => 1);
    $upload->move_to($fh);

    my $city = $c->model('City')->get_name_with_uf($c->param('city_id'))->hash->{name};

    my $email = Andi::Minion::Task::SendEmail::Mailer::Template->new(
        to       => 'carlos@appcivico.com',
        from     => 'no-reply@appcivico.com',
        subject  => 'Upload de plano municipal',
        template => get_data_section('template.tt'),
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

__DATA__

@@ template.tt

Nome: [%name%]
<br>
Email: [%email%]
<br>
Cidade: [%city%]
