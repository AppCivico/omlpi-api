package Andi::Controller::Data::DownloadIndicator;
use Mojo::Base 'Andi::Controller';

use Data::Printer;

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $year      = $c->param('year') || $c->model('Data')->get_max_year()->hash->{year};
    my $locale_id = $c->param('locale_id');

    $c->render_later();
    return $c->model('Data')->download_indicator(locale_id => $locale_id, year => $year)
      ->then(sub {
          my $file = shift;

          return $c->render_file(
              filepath => $file->filename,
              filename => 'Indicador.xlsx',
              format   => 'xlsx',
              cleanup  => 0,
              #cleanup  => 1,
          );
      })
      ->catch(sub {
          return $c->reply_exception(@_);
      });
}

1;
