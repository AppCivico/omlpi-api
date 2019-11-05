package Andi::Controller::Locales;
use Mojo::Base 'Andi::Controller';
use DDP;

sub list {
    my $c = shift;

    return $c->render(json => $c->model('Locale')->build_list(), status => 200);
}

1;
