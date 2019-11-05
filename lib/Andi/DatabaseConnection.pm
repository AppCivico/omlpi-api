package Andi::DatabaseConnection;
use Mojo::Base -strict;
use FindBin qw($RealBin);
use Config::General;

require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(get_mojo_pg);

use Andi::Logger;
use Mojo::Pg;

sub get_mojo_pg {
    # TODO Carregar as envs
    undef $Andi::Logger::instance;
    return Mojo::Pg->new(
        sprintf(
            'postgresql://%s:%s@%s:%s/%s',
            $ENV{POSTGRESQL_USER}     || 'postgres',
            $ENV{POSTGRESQL_PASSWORD} || 'trustme',
            $ENV{POSTGRESQL_HOST}     || 'localhost',
            $ENV{POSTGRESQL_PORT}     || 5432,
            $ENV{POSTGRESQL_DBNAME}   || 'omlpi_dev',
        )
    );
}

1;