#!/usr/bin/env perl
use Mojo::Base -strict;
use FindBin qw($RealBin);
use lib "$RealBin/../../../lib";
use open ':locale';

use OMLPI::DatabaseConnection;
use DDP;

my $pg = OMLPI::DatabaseConnection->get_mojo_pg();
my $dbh = $pg->db->dbh;

use Tie::Handle::CSV;
use Data::Printer;
use Data::Dumper;

my $csv = Tie::Handle::CSV->new("$RealBin/RELATORIO_DTB_BRASIL_MUNICIPIO.csv", header => 1);
while (my $r = <$csv>) {
    my $id = $r->{'Código Município Completo'};
    my $name = $r->{'Nome_Município'};
    my $state_id = $r->{'UF'};

    printf
       "UPDATE city SET name = %s WHERE id = %d AND state_id = %d;\n",
       $dbh->quote($name), $id, $state_id;
}
close $csv;
