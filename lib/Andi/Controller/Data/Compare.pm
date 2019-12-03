package Andi::Controller::Data::Compare;
use Mojo::Base 'Andi::Controller';

sub get {
    my $c = shift;

    $c->openapi->valid_input or return;

    my $locale_ids = $c->every_param('locale_id');
    my $year       = $c->param('year');

    $c->_validate_comparison(@{$locale_ids});

    my $res = $c->model('Locale')->get(locale_id => $locale_ids, year => $year);

    return $c->render(json => { comparison => $res->expand->hashes }, status => 200 );
}

sub _validate_comparison {
    my ($c, @locale_ids) = @_;

    my %grant = (
        city    => [qw(state country region)],
        state   => [qw(region city)],
        region  => [qw(city country state)],
        country => [qw(city region)],
    );
    my ($first, $second) = map { $_->{type} } $c->pg->db->select("locale", [qw(type)], { id => \@locale_ids })->hashes->each;

    my %options = map { $_ => 1 } @{ $grant{$first} };
    if (exists $options{$second}) {
        return 1;
    }

    die {
        errors => [
            {
                message => "Can't compare a ${first} with a ${second}.",
                path    => "/locale_id/1",
            }
        ],
        status => 400,
    };
}

1;
