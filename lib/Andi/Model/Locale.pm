package Andi::Model::Locale;
use Mojo::Base 'MojoX::Model';

sub build_list {
    my $self = shift;

    return $self->app->pg->db->select_p(
        "locale",
        [qw<id name type>],
    );
}

1;
