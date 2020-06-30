package OMLPI::Controller::Data;
use Mojo::Base 'OMLPI::Controller';

use Tie::IxHash;

sub get {
    my $c = shift;

    $c->openapi->valid_input() or return;

    my $area_id   = $c->param('area_id');
    my $locale_id = $c->param('locale_id');
    my $year      = $c->param('year') || $c->model('Data')->get_max_year(locale_id => $locale_id)->hash->{year};

    my $res = $c->model('Data')
      ->get(locale_id => $locale_id, area_id => $area_id, year => $year)
      ->expand()
      ->hash();

    for my $indicator (@{$res->{indicators}}) {
        my @subindicators = sort { $a->{id} <=> $b->{id} } @{ delete $indicator->{subindicators} };

        my %agg;
        #tie(%agg, 'Tie::IxHash');
        tie(%agg, 'DB_File');
        for my $subindicator (@subindicators) {
            my $classification = delete $subindicator->{classification};
            $agg{$classification} //= {
                data           => [],
                classification => $classification,
            };
            push @{ $agg{$classification}->{data} }, $subindicator;
        }

        $indicator->{subindicators} = [values %agg];
    }

    return $c->render(json => { locale => $res }, status => 200);
}

1;
