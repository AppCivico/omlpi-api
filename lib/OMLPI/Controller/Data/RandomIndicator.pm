package OMLPI::Controller::Data::RandomIndicator;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input() or return;

    my $locale_id_ne = $c->every_param('locale_id_ne');
    my $res = $c->model('Data')->get_random_indicator(locale_id_ne => $locale_id_ne);

    return $c->render(json => { locales => $res->expand->hashes }, status => 200);
}

1;
