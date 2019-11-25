package Andi::Controller;
use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw(blessed);

sub reply_not_found {
    die {
        errors => [
            {
                message => "Page not found",
                path    => undef,
            }
        ],
        status => 404,
    };
}

sub reply_forbidden {
    die {
        errors => [
            {
                message => "Forbidden",
                path    => undef,
            }
        ],
        status => 403,
    };
}

sub reply_method_not_allowed {
    die {
        errors => [
            {
                message => "Method not allowed",
                path    => undef,
            }
        ],
        status => 405,
    };
}

sub reply_exception {
    my $c   = shift;
    my $err = shift;
    my $ret = eval { &_reply_exception($c, $err) };
    if ($@) {
        $c->app->log->fatal("reply_exception generated an exception!!!");
        $c->app->log->fatal($@);
        die {
            errors => [
                {
                    message => "Internal server error",
                    path    => undef,
                }
            ],
            status => 500,
        };
    }
    return $ret if $ret;
}

sub _reply_exception {
    my $c        = shift;
    my $an_error = shift;

    if ($an_error) {

        if (ref $an_error eq 'HASH' && ref $an_error->{errors} eq 'ARRAY') {
            my $status = $an_error->{status} || 400;

            return $c->render(json => $an_error, status => $status);
        }
        elsif (ref $an_error eq 'REF' && ref $$an_error eq 'ARRAY' && @$$an_error == 2) {

            return $c->render(
                json   => {error => 'form_error', message => {$$an_error->[0] => $$an_error->[1]}},
                status => 400,
            );
        }
        elsif (ref $an_error eq 'DBIx::Class::Exception'
            && $an_error->{msg} =~ /duplicate key value violates unique constraint/)
        {
            $c->app->log->info('Exception treated: ' . $an_error->{msg});

            return $c->render(
                json => {
                    error   => 'duplicate_key_violation',
                    message => 'You violated an unique constraint! Please verify your input fields and try again.'
                },
                status => 400,
            );
        }
        elsif (ref $an_error eq 'DBIx::Class::Exception' && $an_error->{msg} =~ /is not present/) {
            my ($match, $value) = $an_error->{msg} =~ /Key \((.+?)\)=(\(.+?)\)/;

            return $c->render(
                json => {
                    error   => 'fk_violation',
                    message => sprintf 'key=%s value=%s cannot be found on our database',
                    $match, $value
                },
                status => 400,
            );
        }
        elsif (ref $an_error eq 'HASH' && $an_error->{error_code}) {
            $c->app->log->info('Exception treated: ' . $an_error->{message});

            return $c->render(
                json   => {error => 'generic_exception', message => $an_error->{message}},
                status => $an_error->{error_code} || 500,
            );
        }
        elsif (ref $an_error eq 'HASH' && $an_error->{error}) {
            $c->app->log->info('Exception treated: ' . $c->app->dumper($an_error));

            return $c->render(json => {error => delete $an_error->{error}, %$an_error}, status => 400,);
        }

        $c->app->log->fatal(blessed($an_error)
              && UNIVERSAL::can($an_error, 'message') ? $an_error->message : $c->app->dumper($an_error));
    }

    return $c->render(json => {error => 'internal_server_error', message => "Internal server error"}, status => 500);
}

1;
