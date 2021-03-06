Param(
   [Parameter(Mandatory=$True, HelpMessage="The Directory of Nessus Files to Process")]
   [ValidateScript({Test-Path $(resolve-path $_)})]
   [string] $path = ".",
   
   [Parameter(Mandatory=$True, HelpMessage="The AccessDB to import results to")]
   [ValidateScript({Test-Path $_ })]
   [string]$AccessDB,
   
   [Alias("p")]
   [ValidateRange(1,99)] 
   [int]$maxPool = '1'   
   )

Import-Module PSNessusDB
  
$rpath = resolve-path $path

get-childitem -d $rpath -include *.nessus -recurse -force | Import-PSNessusDB -d $AccessDB