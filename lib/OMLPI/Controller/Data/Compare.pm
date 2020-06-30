package OMLPI::Controller::Data::Compare;
use Mojo::Base 'OMLPI::Controller';

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

    use DDP;

    my $res = $compare->expand->hashes
      ->map(sub {
          $_
      });

    p $res->[0]->{indicators}->[1];

    exit 0;

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
