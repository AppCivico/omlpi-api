package OMLPI::Controller::Data::Resume;
use Mojo::Base 'OMLPI::Controller';

use Data::Printer;

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $year      = $c->param('year');
    my $locale_id = $c->param('locale_id');

    # Get max year
    $year = $c->model('Data')->get_max_year(locale_id => $locale_id)->hash->{year}
      if not defined $year;

    my $attachment = $c->model('Data')->get_resume(locale_id => $locale_id, year => $year);
    my $size = -s $attachment;
    $size > 0 or return $c->reply_internal_server_error();

    my $locale_name = $c->pg->db->select('locale', [qw(name)], { id => $locale_id })->hash->{name};

    return $c->render_file(
        filepath => $attachment,
        filename => "RelatorioObserva_${locale_name}.pdf",
        format   => 'pdf',
        cleanup  => 1,
    );
}

1;
