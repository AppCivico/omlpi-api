package Andi::Controller::Locales;
use Mojo::Base 'Andi::Controller';

sub list {
    my $c = shift;

    $c->render_later();
    $c->model('Locale')->list()
      ->then(sub {
          my $results = shift;

          return $c->render(json => { locales => $results->hashes }, status => 200);
      })
      ->catch(sub {
          my $err = shift;
          $c->app->log->error($err);
          $c->reply_exception();
      });
}

sub read {
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

sub compare {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $locale_ids = $c->every_param('locale_id');
    my $year       = $c->param('year');

    $c->_validate_comparison(@{$locale_ids});
    $year = $c->model('Locale')->get_max_year()->hash->{year}
      if not defined $year;

    my $res = $c->model('Locale')->get(locale_id => $locale_ids, year => $year);

    return $c->render(json => { comparison => $res->expand->hashes }, status => 200 );
}

sub _validate_comparison {
    my ($c, @locale_ids) = @_;

    my %grant = (
        city    => [qw(state country region)],
        state   => [qw(region)],
        region  => [qw(country)],
        country => [],
    );
    my ($first, $second) = map { $_->{type} } $c->pg->db->select("locale", [qw(type)], { id => \@locale_ids })->hashes->each;

    my %options = map { $_ => 1 } @{ $grant{$first} };
    if (exists $options{$second}) {
        return 1;
    }

    die {
        errors => [
            {
                message => "Can't compare a ${first} with a ${second}.",
                path    => "/locale_id/1",
            }
        ],
        status => 400,
    };
}

1;
