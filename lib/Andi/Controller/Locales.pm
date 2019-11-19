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

    my $locale_id = $c->param('localeId');

    $c->render_later();
    $c->model('Locale')->get(locale_id => $locale_id)
      ->then(sub {
          my $res = shift;
          return $c->render(json => { locale => $res->expand->hash }, status => 200);
      })
      ->catch(sub {
          my $err = shift;
          $c->app->log->error($err);
          $c->reply_exception();
      });
}

1;
