function Convert-StringToBase64 {
  <#
  .SYNOPSIS
  Converts a string into a Base64 String
  .DESCRIPTION
  Converts a string into a Base64 String
  .EXAMPLE
  Convert-StringToBase64 -String "This is my String"
  .PARAMETER Input
  The String to convert
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
      HelpMessage='String to Convert')]
    [string]$string
  )

  begin {

  }

  process {

        write-verbose "Converting $string"

        $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string)
        $b64 = [System.Convert]::ToBase64String($bytes)
        Write-Output $b64
  }
  
  end{
     
  }
}

function Convert-Base64toString {
  <#
  .SYNOPSIS
  Converts a Base64 String to and String
  .DESCRIPTION
  Converts a Base64 String to and String
  .EXAMPLE
  Convert-Base64toString -String "VGhpcyBpcyBteSBTdHJpbmc="
  .PARAMETER Input
  The String to convert
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
      HelpMessage='String to Convert')]
    [string]$string
  )

  begin {

  }

  process {

    write-verbose "Converting $String"

    $bytes2  = [System.Convert]::FromBase64String($String)
    $output = [System.Text.Encoding]::UTF8.GetString($bytes2)
    Write-Host $output
  }
  
  end{
     
  }
}

