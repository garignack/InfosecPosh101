Param (
[Parameter(Mandatory=$True)]
[string] $string
)

$bytes  = [System.Text.Encoding]::UTF8.GetBytes($string)
$b64 = [System.Convert]::ToBase64String($bytes)
Write-Host $b64

$bytes2  = [System.Convert]::FromBase64String($b64)
$output = [System.Text.Encoding]::UTF8.GetString($bytes2)
Write-Host $output
