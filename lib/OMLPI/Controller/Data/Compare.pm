package OMLPI::Controller::Data::Compare;
use Mojo::Base 'OMLPI::Controller';

use Tie::IxHash;

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $locale_id = $c->param('locale_id');
    my $year      = $c->param('year');

    my $type = $c->model('Locale')->get_type($locale_id);

    #$c->_validate_comparison($locale_id);

    my $compare = $type eq 'country'
        ? $c->model('Compare')->compare_country(locale_id => $locale_id, year => $year)
        : $c->model('Compare')->compare(locale_id => $locale_id, year => $year)
    ;

    my $res = $compare->expand->hashes;

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

    return $c->render(json => { comparison => $res }, status => 200 );
}

sub _validate_comparison {
    my ($c, $locale_id) = @_;

    my $type = $c->model('Locale')->get_type($locale_id);
    #if (!($type =~ m{^(city|state)$})) {
    if ($type eq 'country') {
        die {
            errors => [
                {
                    message => "Can't compare with a ${type}.",
                    path    => "/locale_id/0",
                }
            ],
            status => 400,
        };
    }
}

1;
