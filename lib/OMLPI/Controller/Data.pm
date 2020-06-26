package OMLPI::Controller::Data;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $area_id   = $c->param('area_id');
    my $locale_id = $c->param('locale_id');
    my $year      = $c->param('year') || $c->model('Data')->get_max_year(locale_id => $locale_id)->hash->{year};

    my $res = $c->model('Data')->get(locale_id => $locale_id, area_id => $area_id, year => $year);

    return $c->render(json => { locale => $res->expand->hash }, status => 200);
}

1;
