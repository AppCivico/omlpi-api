package Andi::Controller::Locales;
use Mojo::Base 'Andi::Controller';
use DDP;

sub list {
    my $c = shift;

    $c->render_later;
    $c->model('Locale')->build_list()
      ->then(sub {
          my $results = shift;
          my @res = [$results->hashes];
          p \@res;
          return $c->render(json => {}, status => 200);

      })
      ->catch(sub {

      });
}

1;
