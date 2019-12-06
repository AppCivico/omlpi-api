package Andi::Controller::Data::Download;
use Mojo::Base 'Andi::Controller';

use Data::Printer;

sub get {
    my $c = shift;

    $c->render_later();
    return $c->model('Data')->get_all_data()
      ->then(sub {
          p \@_;

          ...
      })
      ->catch(sub {
          return $c->reply_exception(@_);
      });
}

1;
