package Andi::Model::Locale;
use Mojo::Base 'MojoX::Model', -signatures;

sub build_list {
    my $self = shift;

    my $pg = $self->app->pg;
    return $pg->db->select_p(
        "locale",
        [qw<id name type>],
        undef,
        { limit => 10 }
    );
}

1;
