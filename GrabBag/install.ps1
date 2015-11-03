Function Get-OperatingSystemVersion
{
 (Get-WmiObject -Class Win32_OperatingSystem).Version
} #end Get-OperatingSystemVersion

Function Test-ModulePath
{
 $VistaPath = "$env:userProfile\documents\WindowsPowerShell\Modules"
 $XPPath =  "$env:Userprofile\my documents\WindowsPowerShell\Modules"
 if ([int](Get-OperatingSystemVersion).substring(0,1) -ge 6)
   {
     if(-not(Test-Path -path $VistaPath))
       {
         New-Item -Path $VistaPath -itemtype directory | Out-Null
       } #end if
   } #end if
 Else
   { 
     if(-not(Test-Path -path $XPPath))
       {
         New-Item -path $XPPath -itemtype directory | Out-Null
       } #end if
   } #end else
} #end Test-ModulePath

Function Copy-Module([string]$name)
{
 $UserPath = $env:PSModulePath.split(";")[0]
 $ModulePath = Join-Path -path $userPath `
               -childpath (Get-Item -path $name).directory.basename
 If(-not(Test-Path -path $modulePath))
   {
    New-Item -path $modulePath -itemtype directory | Out-Null
    Copy-item -path $name -destination $ModulePath | Out-Null
   }
 Else
   {
    Copy-item -path $name -destination $ModulePath | Out-Null
   }
}
# *** Entry Point to Script ***
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$path = $scriptPath +"\PSNessusDB"
write-host $path
Test-ModulePath
Get-ChildItem -Path $path -Include *.psm1,*.psd1,*.ps1 -Recurse |
Foreach-Object { Copy-Module -name $_.fullName }
