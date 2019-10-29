package Andi::Controller;
use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw(blessed);

sub reply_not_found {
    my $c = shift;

    die {error => 'Page not found', status => 404,};
}

sub reply_forbidden {
    my $c = shift;

    die {error => 'permission_denied', message => 'Forbidden', status => 403,};
}

sub reply_method_not_allowed {
    my $c = shift;

    die {error => 'method_not_allowed', message => 'Method not allowed', status => 405,};
}

sub reply_exception {
    my $c   = shift;
    my $err = shift;
    my $ret = eval { &_reply_exception($c, $err) };
    if ($@) {
        $c->app->log->fatal("reply_exception generated an exception!!!");
        $c->app->log->fatal($@);
        die {error => "Internal server error", status => 500,};
    }
    return $ret if $ret;
}

sub _reply_exception {
    my $c        = shift;
    my $an_error = shift;

    if ($an_error) {

        if (ref $an_error eq 'HASH' && exists $an_error->{error}) {
            my $status = delete $an_error->{status} || 400;

            return $c->render(json => $an_error, status => $status,);
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

    return $c->render(json => {error => "Internal server error"}, status => 500,);
}

sub validate_request_params {
    my ($c, %fields) = @_;

    foreach my $key (keys %fields) {
        my $me   = $fields{$key};
        my $type = $me->{type};

        my $val = $c->req->params->to_hash->{$key};
        $val = '' if !defined $val && $me->{clean_undef};

        if (defined($val) && (exists $me->{min_length} || exists $me->{max_length})) {
            my $len     = length $val;
            my $min_len = $me->{min_length};
            my $max_len = $me->{max_length};
            die {error => 'form_error', message => {$key => 'invalid'}, status => 400}
              if (defined($min_len) && $len < $min_len) || (defined($max_len) && $len > $max_len);
        }

        if (!defined $val && $me->{required} && !($me->{undef_is_valid} && !defined $val)) {
            die {error => 'form_error', message => {$key => 'missing'}, status => 400,};
        }

        if (
               defined $val
            && $val eq ''
            && (   $me->{empty_is_invalid}
                || $type eq 'Bool'
                || $type eq 'Int'
                || $type eq 'Num'
                || ref $type eq 'MooseX::Types::TypeDecorator')
          )
        {

            die {error => 'form_error', message => {$key => 'empty_is_invalid'}, status => 400,};
        }

        next unless $val;

        my $cons = Moose::Util::TypeConstraints::find_or_parse_type_constraint($type);

        if (!defined $cons) {
            die {error => 'form_error', message => "Unknown type constraint '$type'", status => 400,};
        }

        if (!$cons->check($val)) {
            die {error => 'form_error', message => {$key => 'invalid'}, status => 400,};
        }
    }
}

1;