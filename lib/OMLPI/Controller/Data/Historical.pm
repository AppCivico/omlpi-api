package OMLPI::Controller::Data::Historical;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $locale_id = $c->param('locale_id');

    my $res = $c->model('Data')->get_historical(locale_id => $locale_id);

    return $c->render(json => { historical => $res->expand->hashes }, status => 200 );
}

1;
