package OMLPI::Model::PlanUpload;
use Mojo::Base 'MojoX::Model';

use File::Temp;
use Digest::SHA;
use Scope::OnExit;
use Mojo::Util qw(decode);
use OMLPI::Utils qw(mojo_home);
#use IO::Compress::Zip qw(zip $ZipError);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use OMLPI::Minion::Task::SendEmail::Mailer::Template;


use Data::Printer;

sub create {
    my ($self, %args) = @_;

    # File upload
    my $upload = $args{file};
    my $fh = File::Temp->new(UNLINK => 1);
    $upload->move_to($fh);

    # Checksum
    my $sha256 = Digest::SHA->new(256);
    $sha256->addfile($fh);
    my $digest = $sha256->hexdigest;

    # Check if this upload already submitted
    my $db = $self->app->pg->db;
    my $plan_upload = $db->select(
        'plan_upload',
        [qw(id)],
        {
            email         => $args{email},
            locale_id     => $args{locale_id},
            sha256_digest => $digest,
            created_at    => {'>' => \"NOW() - '15 minutes'::interval"},
        }
    )->hash;
    if (defined($plan_upload)) {
        return $plan_upload->{id};
    }

    # Zip file
    my $zip = Archive::Zip->new();
    my $filename = $upload->filename;
    $zip->addFile($fh->filename, $filename);

    my $zipfile = File::Temp->new(UNLINK => 0, SUFFIX => ".zip");
    $zip->writeToFileNamed($zipfile->filename);

    on_scope_exit {
        unlink $zipfile->filename or die $!;
    };

    close $fh;

    # Locale
    my $locale_id   = $args{locale_id};
    my $locale      = $self->app->model('Locale')->get_state_or_city_name_with_uf($locale_id)->hash;
    my $locale_type = $locale->{type};
    if (!$locale_type =~ m{^(city|state)$}) {
        die {
            errors => [
                {
                    message => "Expected a city or a state - got $locale_type.",
                    path    => '/locale_id',
                },
            ],
            status => 400,
        };
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
            name  => $args{name},
            email => $args{email},
            city  => $locale->{name},
        },
        attachments => [{
            fh   => $zipfile,
            name => $filename,
        }]
    )->build_email();

    $plan_upload = eval {
        my $tx = $db->begin();

        $self->app->minion->enqueue(send_email => [ $email->as_string() ]);

        close $zipfile;

        # Save on database
        my $pu = $db->insert('plan_upload',
            {
                name          => $args{name},
                email         => $args{email},
                locale_id     => $locale_id,
                filename      => $upload->filename,
                sha256_digest => $digest,
            },
            { returning => 'id'}
        )->hash;

        $tx->commit();

        return $pu;
    };
    if ($@) {
        $self->app->log->error($@);
        die $@;
    }

    return $plan_upload->{id};
}

1;
