$uri = "www.hack3rcon.org"
$content2 = Invoke-WebRequest $uri
$content2.links | foreach{
    $_.href
}