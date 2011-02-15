#!/usr/bin/env perl
use strict;
use warnings;
use App::Termcast::Server::IRC;
use Cwd;

die "Arg (socket path) required" if !@ARGV;

my $socket = Cwd::abs_path($ARGV[0]);

my $engine = App::Termcast::Server::IRC->new(socket => $socket);
