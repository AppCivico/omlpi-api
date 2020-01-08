package OMLPI::DatabaseConnection;
use Mojo::Base -strict;

require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(get_mojo_pg);

use Mojo::Pg;
use Config::General;
use OMLPI::Logger;

sub get_mojo_pg {
    undef $OMLPI::Logger::instance;

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
