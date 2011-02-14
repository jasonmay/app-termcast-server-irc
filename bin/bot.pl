#!/usr/bin/env perl
use strict;
use warnings;
use IM::Engine;
use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use YAML qw(LoadFile);

die "Arg (unix socket path) required" unless @ARGV;


my $host = 'jarsonmar.org';
my $config = LoadFile('etc/config.yml');

my $engine = IM::Engine->new(
    interface => {
        protocol => 'IRC',
        credentials => {
            server   => "irc.cplug.net",
            port     => 6667,
            channels => ["#bot"],
            nick     => "TCbot",
        },
    },
);

my $h;
my $socket = tcp_connect 'unix/', $ARGV[0], sub {
    warn "connected";
    my $fh = shift;
    $h = AnyEvent::Handle->new(
        fh => $fh,
        on_error => sub {
            my ($h, $fatal, $error) = @_;
            if ($fatal) {
                $h->destroy;
                warn $error;
                AE::cv->send;
            }
        },
        on_read => sub {
            my $h = shift;
            $h->push_read(
                json => sub {
                    my ($h, $data) = @_;
                    require JSON; warn JSON->new->pretty->encode($data);
                    if ($data->{notice}) {
                        if ($data->{notice} eq 'connect') {
                            my $channel = IM::Engine::Outgoing::IRC::Channel->new(
                                channel => '##netmonster',
                                message => sprintf(
                                    q[%s started termcasting on %s],
                                        $data->{connection}{user},
                                        $host,
                                    ),
                            );
                            $engine->send_message($channel);
                        }
                    }
                },
            );
        },
    );
};

$engine->run;