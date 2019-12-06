package Andi::Controller::Data::Download;
use Mojo::Base 'Andi::Controller';

use Data::Printer;

sub get {
    my $c = shift;

    $c->render_later();
    return $c->model('Data')->get_all_data()
      ->then(sub {
          my $file = shift;

          return $c->render_file(
              filepath => $file->filename,
              filename => 'report.xlsx',
              format   => 'xlsx',
              cleanup  => 1,
          );
      })
      ->catch(sub {
          return $c->reply_exception(@_);
      });
}

1;
