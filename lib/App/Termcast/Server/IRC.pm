package App::Termcast::Server::IRC;
use Moose;
use AnyEvent::Socket;
use IM::Engine;
use IM::Engine::Outgoing::IRC::Channel;
use YAML;
use Cwd;

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my $self = shift;
    YAML::LoadFile('etc/config.yml');
}

has engine => (
    is      => 'ro',
    isa     => 'IM::Engine',
    lazy    => 1,
    builder => '_build_engine',
);

sub _build_engine {
    my $self = shift;

    my $engine = IM::Engine->new(
        interface => $self->config,
    );

    return $engine;
}

has socket => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has termcast_handle => (
    is  => 'rw',
    isa => 'AnyEvent::Handle',
);

sub _start_termcast_checker {
    my $self = shift;
    tcp_connect 'unix/', Cwd::abs_path($self->socket), sub {
        my $fh = shift or die $!;
        $self->_tcp_connect($fh);
    };
}

sub _tcp_connect {
    my $self = shift;
    my $fh = shift;

    my $h = AnyEvent::Handle->new(
        fh => $fh,
        on_read => sub { $self->_read_event(@_) },
    );

    $self->termcast_handle($h);
}

sub _read_event {
    my $self = shift;
    my ($h) = @_;

    $h->push_read(
        json => sub { $self->_handle_tc_data(@_); }
    );
}

sub _handle_tc_data {
    my $self = shift;
    my ($h, $data) = @_;

    if ($data->{notice} eq 'connect') {
        foreach my $channel (@{ $self->config->{credentials}->{channels} }) {
            $self->_respond($channel, $data);
        }
    }
}

sub _respond {
    my $self = shift;
    my ($channel_name, $data) = @_;
    my $channel = IM::Engine::Outgoing::IRC::Channel->new(
        channel => $channel_name,
        message => sprintf(
            q[%s started termcasting: http://%s/tv/%s],
            $data->{connection}{user}, 'jarsonmar.org:5000', $data->{connection}{session_id},
        ),
    );
    $self->engine->send_message($channel);
}

sub run {
    my $self = shift;
    $self->_start_termcast_checker();
    $self->engine->run(@_)
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
