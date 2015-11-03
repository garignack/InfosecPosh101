function Get-Something {
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computername
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
      HelpMessage='What computer name would you like to target?')]
    [Alias('host')]
    [ValidateLength(3,30)]
    [string[]]$computername,
		
    [string]$logname = 'errors.txt'
  )

  begin {
  write-verbose "Deleting $logname"
    del $logname -ErrorActionSilentlyContinue
  }

  process {

    write-verbose "Beginning process loop"

    foreach ($computer in $computername) {
      Write-Verbose "Processing $computer"
      # use $computer to target a single computer
	

      # create a hashtable with your output info
      $info = @{
        'info1'=$value1;
        'info2'=$value2;
        'info3'=$value3;
        'info4'=$value4
      }
      Write-Output (New-Object –TypenamePSObject –Prop $info)
    }
  }
}