package Andi::Model::City;
use Mojo::Base 'MojoX::Model';

sub list {
    my ($self, %opts) = @_;

    my $state_id = $opts{state_id};

    return $self->app->pg->db->select_p(
        "city",
        [qw(id name latitude longitude)],
        {
            (
                defined $state_id
                ? ( 'state_id' => $state_id )
                : ()
            ),
        },
        { order_by => {'-asc' => 'name'} },
    );
}

1;
