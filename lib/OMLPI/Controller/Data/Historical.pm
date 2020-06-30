package OMLPI::Controller::Data::Historical;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $area_id = $c->param('area_id');
    my $locale_id = $c->param('locale_id');

    my $res = $c->model('Historical')->get_historical(locale_id => $locale_id, area_id => $area_id);

    return $c->render(json => { historical => $res->expand->hashes }, status => 200 );
}

1;
