function Import-PSNessusDB{ 
	[CmdletBinding()] 
	param ( 
		[parameter(Mandatory=$True, HelpMessage="The Directory of Nessus Files to Process",
	   		   ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("f")]
		[Alias("file")]
		[ValidateScript({Test-Path $_ })]
		[string]$FullName, #Use of the $FullName variable allows for pipeline passing of files from Get-ChildItem

	  	[Parameter(Mandatory=$True, HelpMessage="AccessDB to import results to")]
	   	[Alias("d")]
	   	[ValidateScript({Test-Path $_ })]
	  	[string]$AccessDB,

	   	[Parameter(Mandatory=$False, HelpMessage="The Log File to Write Logging information to, if not present will log to the Access DB name .log")]
	   	[Alias("l")]
	   	[string]$LogFileName,

		[Parameter(Mandatory=$False, HelpMessage="Enable All Logging")]
		[switch]$Trace,
		[Parameter(Mandatory=$False, HelpMessage="Disable All Logging")]
		[switch]$NoLog


	)
	# Setup Processing Environment.  
	# If multiple files are passed from the pipeline, this will only be invoked once.
	# http://ss64.com/ps/syntax-function-input.html
	BEGIN{
		$scriptPath = $PSScriptRoot
		$AccessDB = resolve-path $AccessDB
		$outDir = [System.IO.Path]::GetDirectoryName($AccessDB)
		$psfile = resolve-path "$scriptPath\add-NessusHost.ps1"
		
		#*** Module Imports ***  TODO: Build Module Manifest and Remove
		Import-Module "$scriptPath\AccessDBFunctions.ps1"
		Import-Module "$scriptPath\psNessus-Utilities.ps1"
		Import-Module "$scriptPath\PS-Log.psm1" -Force
		
		$psfile = resolve-path "$scriptPath\add-NessusHost.ps1" # TODO: Modularize this better to allow for different processing scripts.
		
		#*** Setup Logging ***
		# Logging File
		if (!$LogFileName) { $LogFileName = $outDir + "\" + [System.IO.Path]::GetFilenameWithoutExtension($AccessDB) + ".log"}
		
		try{ 
			Switch-LogFile -Name $LogFileName 
		}
		catch { 
			$LogFileName = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetFilenameWithoutExtension($AccessDB) + ".log"
			Write-Warning "Error creating log file, results will be logged to: $($LogFileName)"
		}
		
		# Set logging level for process.  The most verbose logging flag set wins. 
		[int]$LoggingLevel = $GLOBAL:LogLevel # Defaults to Info Logging
		if ($NoLog) {$LoggingLevel = 8} # Do Not Log
		if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {$LoggingLevel = 3} 
		if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {$LoggingLevel = 2}  
	 	if ($Trace) {$LoggingLevel = 1}
		
		#build Logging Object
		try{
			$log = New-LogFile "Import-PSNessusDB" $LogFileName $LoggingLevel
			$log.Info("Log FileName: $LogFileName") 
		}
		catch{
			Write-Host "Error Creating PS-Log Object"
			Write-Error "$_.Exception.ToString()"
		}

		# Load the C# [PSNessusDB.Cutter] library
		Try {Load-FileCutter} 
		Catch { 
			$log.Debug($_.Exception.ToString())
			$log.Fatal("Cannot Load [PSNessusDB.Cutter] Library")
			Throw "Fatal Error, Exiting"
		}
		
		#Open connection to Access Database.  This is a costly operation, so only call once and pass connection object
		#TODO: Validate cost of Access DB connection
		$log.Verbose("Connecting to Database")
		Try{
			$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0; Data Source=$AccessDB") 
			$conn.Open()
			}
		Catch {			
			$log.Debug($_.Exception.ToString())
			$log.Fatal("Cannot Connect to Database")
			Throw "Fatal Error, Exiting"
		}
		
		#Implement Timings to Measure ReportHost processing statistics
		#Courtesy: Joshua Poehls (Jpoehls)
		#https://github.com/jpoehls/hulk-example/blob/master/_posts/2013/2013-01-24-benchmarking-with-Powershell.md
		$swTotal = New-Object Diagnostics.Stopwatch
		$sw = New-Object Diagnostics.Stopwatch
		
	}#begin 

	# Process $FullName object
	PROCESS{
		$swTotal.Reset()
		$swTotal.start()
		
		$FullName = resolve-path $FullName # To account for if a relative path was given for the File Name.
		$log.Info("-----------------------------")
		$log.Info("Processing File: $([System.IO.Path]::GetFilename($FullName))")
		$log.Info("-----------------------------")
		
		# Build a new Stream Reader and capture the file length
		
		$log.Verbose("Building Stream Reader")
		$sr = new-object system.io.streamreader $FullName, 4096
		$srLEN = $sr.BaseStream.Length
		$log.Verbose("File size is: $($srLen.toString())")
		
		# Check to ensure this is a valid Nessus_V2 file.  This is always on the second line of the file
		$log.Verbose("Checking if file is a Nessus_V2 export")
		[string]$FileHeader = $sr.ReadLine()
		$FileHeader += $sr.ReadLine()
		
		$log.Debug("---- Header ----")
		$log.Debug($FileHeader)
		
		if($FileHeader.contains("<NessusClientData_v2>") -ne $true) {
			$sr.close()
			Remove-Variable sr
			$Log.Fatal("$($FullName) is not a valid Nessus V2 File")
			Break
		}
		#Close the Stream Reader to free up the file for the Cutter Library
		$sr.close()
        $sr.dispose()
		Remove-Variable sr
		
		# --- Log File In Database --- TODO: Modularize this better to allow for different processing scripts.
		# Check if the file has been processed already

		$log.Verbose("Checking if file already Processes")
		$result = Get-AccessData "SELECT ID,ImportDate  from FILES where FileLoc = '$FullName'" $conn
		if ($result) { 
			foreach($row in $result){ 
		    	$log.Warn("File Already Processed on: $($Row.ImportDate)")
				}
		    if ($(Read-Host "Continue Y/N") -ne "Y") {
				$log.Fatal("User cancelled processing due to: File Already Processed")
		        Break
		    }
		}
		
		#Find the Report Host Locations
		$reportName = $null
		$log.Info("Analyzing Nessus File")
		$sw.Start()
		[array] $hostList = Get-ByteMatchLocations $FullName "<ReportHost"
		if(!$hostList) {$log.Fatal("Nessus File does not contain <ReportHost> Nodes "); Break}
		$hostCount = $hostList.count
		$sw.Stop()
		$log.Verbose("Search Time: $($sw.ElapsedMilliseconds.ToString())ms")
		
		# Grab 500 Bytes before the First Host, Convert to a string and find the <Report> node
		$log.Verbose("First Host at: $($hostList[0])")
		if ($hostList[0] -gt 500){$preLoc = $hostList[0] - 500} else {$preLoc = 0} 
		$reportBytes = Get-FileBytes $FullName $preLoc  $hostList[0]  
		$reportString = Convert-BytesToString $reportBytes "UTF8"
		$log.Debug("---- <Report> ----")
		$log.Debug($reportString)
		
		$a = $reportString.indexof("<Report name=") + 14
		$b = $reportString.indexof(" xmlns:")
		if ($b -eq -1) { $b = $line.indexof('>')}
		$reportName = $reportString.substring($a, $b - $a - 1 )
		
		$log.Info("Report: $reportName")
		$log.Info("Hosts: $($hostCount.toString())")
		$log.Info("-----------------------------")
		
		# Record the file being processed and receive the $fileID variable
		$sqlParam = @()
		$sqlValue = @()

		#fill File Entry parameters TODO: Modularize this better to allow for different processing scripts.
		$sqlParam += "reportName"
		$sqlValue += $reportName
		$sqlParam += "FileLoc"
		$sqlValue += $FullName
		$sqlParam += "FileName"
		$sqlValue += $(split-path $FullName -leaf -resolve)
		$sqlParam += "ImportDate"
		$sqlValue += get-date
		
		$fileID = add-AccessData "Files" $sqlParam $sqlValue $conn
		
		$timing = @()
		[int] $intHostsProcessed = 0
		
		Write-Progress -activity "Processing $($reportName)" -status "Hosts: $($intHostsProcessed)/ $($hostCount)" -percentComplete (($intHostsProcessed / $hostCount)  * 100)
		
		for ($i=0; $i -le $hostCount – 1; $i++)
   		{
			$sw.Reset()
			$sw.Start()
			Try {
				
				#convert the ReportHost string into an XML object
                $startLoc = $hostList[$i]
		        if ($i -eq $hostCount -1) {
					# If this is the final Host, we won't have an end location
					# so we read to the end of the file
					$endLoc = -1				
				} else {
                    $endLoc = $hostList[($i + 1)]		
				}
					[string] $hostString = Get-FileString $FullName $startLoc $endLoc "UTF8"
                    
                    $endnodeloc = $hostString.IndexOf("</ReportHost>")
                    
                    if ($endnodeloc -eq -1){
                        $log.Error("Error Processing ReportHost entry at $($startLoc) -> $($endLoc)")
                        $log.Error("Cannot find end </ReportHost>, is this a valid node?")
                        $log.Debug("----------------Last 250 Bytes of File--------------")
                        $log.Debug($hostString.Substring(($hostString.length - 250 ),250))
                        Continue;
                    } else {
                    
                       $hostString = $hostString.Substring(0,($endnodeloc+13)) #Ensure that the string object only include the <ReportHost>...</ReportHost> information
					   $hostString = $hostString.Replace("><HostProperties>"," xmlns:cm=`"http://www.nessus.org/cm`"><HostProperties>") # Add the Nessus XML Namespace back on the xml object
					   [xml]$xmlHost = $hostString
                    }
			}
			Catch {
				$log.Error("Error Processing ReportHost entry at $($startLoc) -> $($endLoc)")
				$log.Debug($_.Exception.toString())
				Continue;
			}
			
			$log.Verbose("Host Retrieval: $($sw.ElapsedMilliseconds.ToString())ms")
	        # Process the host XML object
	        
	            $log.Info("Processing[$($hostlist[$i])]: $($xmlhost.ReportHost.name)")
	            & $psfile $xmlhost $accessDB $fileID
	            
	            $intHostsProcessed = $intHostsProcessed + 1
            
			$sw.Stop()
			$timing += $sw.elapsed
			$log.Verbose("Host Time: $($sw.ElapsedMilliseconds.ToString())ms") 
			Write-Progress -activity "Processing $($reportName)" -status "Hosts: $($intHostsProcessed)/ $($hostCount)" -percentComplete (($intHostsProcessed / $hostCount)  * 100)
			
        }
		    $swTotal.stop()
			$stats = $timing | Measure-Object -Average -Minimum -Maximum -Property Ticks
			$log.Info("-----------------------------")
			$log.info("Completed: $reportName")
			$log.info("Host Avg: $((New-Object System.TimeSpan $stats.Average).TotalMilliseconds)ms")
    		$log.info("Host Min: $((New-Object System.TimeSpan $stats.Minimum).TotalMilliseconds)ms")
    		$log.info("Host Max: $((New-Object System.TimeSpan $stats.Maximum).TotalMilliseconds)ms")
			$log.info("Parsing Total: $($swTotal.Elapsed)")
			$log.Info("-----------------------------")
			
	}#process

	END{
		$conn.close()
		$conn = $null
	}#end

	<# 
	.SYNOPSIS
		Imports a Nessus_V2 file into a Microsoft Access Database

	.DESCRIPTION
		A Powershell cmdlet that takes a Nessus_V2 file as an input and parses it into an Access Database. 
		Accepts $Fullname parameters from the pipeline for processing multiple files at once.
		Utilizes a multi-level logging module for configurable logging outputs
		Supports --debug and --verbose flags for additional information		

	.PARAMETER  FullName
		Alias: f or file
		Absolute or Relative path to Nessus File.  Accepts Pipeline Inputs
	
	.PARAMETER  AccessDB
		Alias: db
		Absolute or Relative path to PSNessusDB Access Database File
		
	.PARAMETER  LogFileName
		Alias: l
		Absolute or Relative path
		
	.PARAMETER  Trace
		Enables All Logging
		
	.PARAMETER NoLog 
		Disables all logging
		
	.EXAMPLE
		Single File Processing
		$file = "C:\Path\To\Scan.nessus"
		$db = "C:\Path\To\Scan.accdb"
		$LogFile = "C:\Path\To\scan.log"
		Import-PSNessusDB -f $File -db $db -l $log  

		Pipeline Processing
		$dir = "C:\Path\To"
		Get-ChildItem -d $dir -include *.nessus -recurse -force | Import-PSNessusDB -f $file -db $db -l $log
		
	.INPUTS
		Nessus_V2 File

	.OUTPUTS
		Microsoft Access Database

	.NOTES
		Credits:
		Joshua Poehls (Jpoehls): https://github.com/jpoehls/hulk-example/blob/master/_posts/2013/2013-01-24-benchmarking-with-Powershell.md
		

	.LINK
		https://github.com/garignack/PS-Nessus-AccessDB
	#>

}