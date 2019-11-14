package Andi::Routes;
use Mojo::Base -strict;

sub register {
    my $r = shift;

    # Types
    $r->add_type(int => qr|[0-9]{1,9}|);

    # PUBLIC ENDPOINTS
    my $locales = $r->route('/locales')->to(controller => 'Locales', action => 'reply_method_not_allowed');
    $locales->get()->to(action => 'list');
    $locales = $locales->route('/:id');
    $locales->get()->to(action => 'read')
}

1;
