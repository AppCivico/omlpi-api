package Andi::Controller::Data;
use Mojo::Base 'Andi::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $area_id   = $c->param('area_id');
    my $year      = $c->param('year');
    my $locale_id = $c->param('locale_id');

    $year = $c->model('Locale')->get_max_year()->hash->{year}
      if not defined $year;

    my $res = $c->model('Locale')->get(locale_id => $locale_id, area_id => $area_id, year => $year);

    return $c->render(json => { locale => $res->expand->hash }, status => 200);
}

1;
