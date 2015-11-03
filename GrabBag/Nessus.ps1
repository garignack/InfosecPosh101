Import-Module Posh-SecMod

$username = read-host
$secstr = read-host -assecurestring
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

New-NessusSession -ComputerName 192.168.1.55 -Credentials $cred

$websites = Import-Csv 'D:\99_Downloads\Top 1000 Websites.csv'
$i=168
do {
	$targets = @()
	for ($j=1; $j -le 8; $j++){
		$targets += $websites[$i].name
		$i = $i + 1
	}
	$scan = Invoke-NessusScan -Index 0 -PolicyID -5 -Targets $targets -Name "Websites-$i"
	Suspend-NessusScan -Index 0 -ScanID $scan.ScanID
	
} until ($i -eq ($websites.count))

do {
	$Scans = Show-NessusScans -Index 2
	$pausedScans = $Scans | Where-Object {$_.Status -eq "paused"}
	$RunningScans = $Scans | Where-Object {$_.Status -ne "paused"}
	
	Write-Host "Checking Scans ** $(Get-Date)**"
	Write-Host "Paused: $($pausedScans.Count)"
	Write-Host "Running: $($Runningscans.Count)"
	
	if ($RunningScans.Count -le 3){
		Write-Host "Starting 8 scans"
		for ($j=0; $j -le 7; $j++){
			Resume-NessusScan -Index 2 -ScanID $pausedScans[$j].ScanID
		}
	}
	Write-Host "Sleeping 3 Minutes ** $(Get-Date)**"	
	Start-Sleep -Seconds 180	
		
} Until ( $pausedScans.Count -eq 0 )

$reports = Get-NessusReports -Index 0
$path = "D:\0_Projects\PS-Nessus-AccessDB\Samples\GoogleTop1000"
$webReports = $reports | Where-Object {$_.reportName -like "Website*"}
foreach ($webReport in $webReports){
	$ReportName = $webReport.reportName
	$reportXML = Get-NessusV2ReportXML -Index 0 -ReportID $webReport.ReportID
	$filePath = "$($path)\$($ReportName).nessus"
	$reportXML.Save($filePath)
	Write-Host $filePath

}

$NessusFiles = gci -path $path -filter "*.nessus" | Sort-Object
[xml] $xmlBase = gc $NessusFiles[0].Fullname

for ($i = 1; $i -le ($NessusFiles.count - 1); $i++){
	[xml] $xmlAdd = gc $NessusFiles[$i].Fullname 
	
	foreach ($reportHost in $($xmlAdd.NessusClientData_v2.Report.ReportHost)){
		$xmlImport = $xmlBase.ImportNode($reportHost, $true)
		$xmlBase.NessusClientData_v2.Report.AppendChild($xmlImport)
	}
}
$xmlBase.Save("$path\All.nessus")
