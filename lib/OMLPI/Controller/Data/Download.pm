package OMLPI::Controller::Data::Download;
use Mojo::Base 'OMLPI::Controller';

sub get {
    my $c = shift;

    $c->res->headers->content_disposition('attachment;filename="OMLPI_Dados.zip";');
    return $c->reply->static('data_spreadsheet.zip');
}

1;
