package OMLPI::Controller::UploadPlan;
use Mojo::Base 'OMLPI::Controller';

use File::Temp;
use Mojo::Util qw(decode);
use OMLPI::Utils qw(mojo_home);
#use IO::Compress::Zip qw(zip $ZipError);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use OMLPI::Minion::Task::SendEmail::Mailer::Template;

use DDP;

sub post {
    my $c = shift;

    $c->openapi->valid_input() or return;

    # File upload
    my $upload = $c->param('file');
    my $fh = File::Temp->new(UNLINK => 1);
    $upload->move_to($fh);

    my $zip = Archive::Zip->new();
    my $filename = $upload->filename;
    $zip->addFile($fh->filename, $filename);

    my $zipfile = File::Temp->new(UNLINK => 0, SUFFIX => ".zip");
    $zip->writeToFileNamed($zipfile->filename);

    close $fh;

    # Locale
    my $locale_id   = $c->param('locale_id');
    my $locale      = $c->model('Locale')->get_state_or_city_name_with_uf($locale_id)->hash;
    my $locale_type = $locale->{type};
    if (!$locale_type =~ m{^(city|state)$}) {
        return $c->render(
            json => {
                errors => [
                    {
                        message => "Expected a city or a state - got $locale_type.",
                        path    => '/locale_id',
                    },
                ],
                status => 400,
            },
            status => 400,
        );
    }

    # Get template
    my $home = mojo_home();
    my $template = $home->rel_file('resources/plan/template.tt')->to_abs;

    # Fix encoding issues
    my $slurp = decode('UTF-8', $template->slurp);

    $filename =~ s/(.*)\.[^.]+$/$1.zip/g;

    my $email = OMLPI::Minion::Task::SendEmail::Mailer::Template->new(
        to       => 'carlos@appcivico.com',
        from     => 'no-reply@appcivico.com',
        subject  => 'Upload de plano',
        template => $slurp,
        vars     => {
            name  => $c->param('name'),
            email => $c->param('email'),
            city  => $locale->{name},
        },
        attachments => [
            {
                fh   => $zipfile,
                name => $filename,
            }
        ]
    )->build_email();

    $c->minion->enqueue(send_email => [ $email->as_string() ]);

    close $zipfile;
    unlink $zipfile->filename or die $!;

    return $c->render(json => {}, status => 200);
}

1;
