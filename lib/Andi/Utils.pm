package Andi::Utils;
use common::sense;

use vars qw(@ISA @EXPORT);

@ISA    = (qw(Exporter));
@EXPORT = qw(is_test env nullif);

sub is_test {
    if ($ENV{HARNESS_ACTIVE} || $0 =~ m{forkprove}) {
        return 1;
    }
    return 0;
}

sub nullif {
    my $value = shift;
    return $value eq shift ? undef : $value;
}

sub env { return $ENV{${\shift}} }

1;
