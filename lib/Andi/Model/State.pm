package Andi::Model::State;
use Mojo::Base 'MojoX::Model';

sub list {
    my $self = shift;

    return $self->app->pg->db->select_p(
        "state",
        [qw(id name)],
        undef,
        { order_by => {'-asc' => 'name'} },
    );
}

1;