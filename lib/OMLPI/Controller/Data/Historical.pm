package OMLPI::Controller::Data::Historical;
use Mojo::Base 'OMLPI::Controller';

use Tie::IxHash;

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $area_id = $c->param('area_id');
    my $locale_id = $c->param('locale_id');

    my $res = $c->model('Historical')
      ->get_historical(locale_id => $locale_id, area_id => $area_id)
      ->expand
      ->hashes;

    # Aggregate the subindicators by the classification
    my $fake_classification_id = 1;
    for my $locale (@{$res}) {
        for my $indicator (@{$locale->{indicators} || []}) {
            my @subindicators = sort { $a->{id} <=> $b->{id} } @{ delete $indicator->{subindicators} };

            my %agg;
            tie(%agg, 'Tie::IxHash');
            for my $subindicator (@subindicators) {
                my $classification = delete $subindicator->{classification};
                $agg{$classification} //= {
                    id             => $fake_classification_id++,
                    data           => [],
                    classification => $classification,
                };
                push @{ $agg{$classification}->{data} }, $subindicator;
            }

            $indicator->{subindicators} = [values %agg];
        }
    }

    return $c->render(json => { historical => $res }, status => 200 );
}

1;
