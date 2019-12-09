package Andi;
use Mojo::Base 'Mojolicious';

use Andi::Config;
use Andi::Controller;
use Andi::Logger;
use Andi::Utils;
use Andi::DatabaseConnection;

sub startup {
    my $self = shift;

    # Config
    Andi::Config::setup($self);
    $self->controller_class('Andi::Controller');

    # Logger
    get_logger();
    $self->plugin('Log::Any' => {logger => 'Log::Log4perl'});

    # Plugins
    $self->plugin('Model');
    $self->plugin('RenderFile');
    $self->plugin('ParamLogger');

    # OpenAPI
    $self->plugin(OpenAPI => {
        plugins => [qw(+SpecRenderer)],
        spec    => $self->static->file("openapi.yaml")->path,
    });

    # Helpers
    $self->helper(pg => sub { state $pg = Andi::DatabaseConnection->get_mojo_pg() });
    $self->helper('reply.exception' => sub { Andi::Controller::reply_exception(@_) });
    $self->helper('reply.not_found' => sub { Andi::Controller::reply_not_found(@_) });
}

1;

