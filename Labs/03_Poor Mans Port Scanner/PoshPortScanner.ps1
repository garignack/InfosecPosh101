# -----------------------------------------------------------------------------
# Script: PoshPortScanner.ps1
# Author: ed wilson, msft
# Date: 02/19/2014 15:17:33
# Keywords: Security, Networking, Tcp/IP, Monitoring
# comments: This script scans a range of IP addresses for web servers listening
# to port 80. It is a useful audit tool, because there are lots of software and
# devices that setup web servers for management, but that do not necessarily
# inform about them.
#
# -----------------------------------------------------------------------------

$port = 80
$net = "192.168.0"
$range = 1..254
foreach ($r in $range)
{
 $ip = "{0}.{1}" -F $net,$r

 if(Test-Connection -BufferSize 32 -Count 1 -Quiet -ComputerName $ip)
   {
     $socket = new-object System.Net.Sockets.TcpClient($ip, $port)
     If($socket.Connected)

       {
        "$ip listening to port $port"
        $socket.Close() }
         }
 }