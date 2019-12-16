package Andi::Controller::Data::DownloadIndicator;
use Mojo::Base 'Andi::Controller';

use Data::Printer;

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $locale_id    = $c->param('locale_id');
    my $indicator_id = $c->param('indicator_id');
    my $year         = $c->param('year') || $c->model('Data')->get_max_year()->hash->{year};

    $c->render_later();
    return $c->model('Data')->download_indicator(locale_id => $locale_id, year => $year, indicator_id => $indicator_id)
      ->then(sub {
          my $file = shift;
          my $locale_name = shift;

          my $filename = sprintf("%s_Indicador_%d.xlsx", $locale_name, $indicator_id);

          return $c->render_file(
              filepath => $file->filename,
              filename => 'Indicador.xlsx',
              format   => 'xlsx',
              cleanup  => 1,
          );
      })
      ->catch(sub {
          return $c->reply_exception(@_);
      });
}

1;
