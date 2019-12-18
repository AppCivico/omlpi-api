package Andi::Model::City;
use Mojo::Base 'MojoX::Model';

sub list {
    my $self = shift;

    return $self->app->pg->db->select_p(
        "city",
        [qw(id name latitude longitude)],
        undef,
        { order_by => {'-asc' => 'name'} },
    );
}

1;
