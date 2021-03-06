$ips = @("10.67.104.11", "10.67.104.15", "10.67.104.21", "10.67.104.22", "10.67.104.23", "10.67.104.30", "10.67.104.33", "10.67.104.37", "10.67.104.41", "10.67.104.43", "10.67.104.52")

$dns = @()
foreach ($ip in $ips) {
    $dnsentry = [System.Net.Dns]::gethostentry($ip) | select -expandproperty Hostname
    if ($dnsentry -eq $ip) {$dnsentry = "Not Available"}
    
    $dns += New-Object PSObject -Property @{
            hostname = $dnsentry
            ip = $ip
            }
}

$dns