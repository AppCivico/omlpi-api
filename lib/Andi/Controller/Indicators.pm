package Andi::Controller::Indicators;
use Mojo::Base 'Andi::Controller';

sub list {
    my $c = shift;

    $c->render_later();
    $c->model('Indicator')->list()
      ->then(sub {
          my $results = shift;

          return $c->render(json => { indicators => $results->expand->hashes }, status => 200);
      })
      ->catch(sub {
          my $err = shift;
          $c->app->log->error($err);
          $c->reply_exception();
      });
}

1;
