package OMLPI::Controller::Data::RandomIndicator;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    my $res = $c->model('Data')->get_random_indicator();

    return $c->render(json => { indicator => $res->expand->hashes }, status => 200 );
}

1;
