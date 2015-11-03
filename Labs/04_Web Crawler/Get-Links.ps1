$urlregex='<a\s+[^>]+?href="(?<Url>[^"]+)"'
$uri = "www.hack3rcon.org"
$webClient = New-Object System.Net.WebClient
[string] $content = $webClient.DownloadString($uri)

$content -match $urlregex