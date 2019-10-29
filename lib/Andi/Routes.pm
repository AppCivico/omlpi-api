package Andi::Routes;
use Mojo::Base -strict;

sub register {
    my $r = shift;

    # Types
    $r->add_type(int => qr|[0-9]{1,9}|);

    # PUBLIC ENDPOINTS
}

1;
