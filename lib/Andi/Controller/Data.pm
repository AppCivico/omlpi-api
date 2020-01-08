package Andi::Controller::Data;
use Mojo::Base 'Andi::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $area_id   = $c->param('area_id');
    my $year      = $c->param('year');
    my $locale_id = $c->param('locale_id');

    my $res = $c->model('Data')->get(locale_id => $locale_id, area_id => $area_id, year => $year);

    return $c->render(json => { locale => $res->expand->hash }, status => 200);
}

1;
