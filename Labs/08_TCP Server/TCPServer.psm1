<#
    .SYNOPSIS
        Module used to create a TCP server locally or remotely as well as send commands to 
        the server to run on the host.

    .DESCRIPTION
        Module used to create a TCP server locally or remotely as well as send commands to 
        the server to run on the host. Quit server by sending 'Exit' or 'Quit' command to server
        or by closing server window. 
        Alternativley, if neither of these are workable, use Stop-Process along with the ProcessID 
        given at server creation to stop the server.

    .NOTES
        Name: TCPServer.psm1
        Author: Boe Prox
        Created: 22 Feb 2014
        Version History
            Version 1.1 -- 24 Feb 2014
                -Broke out commonly used commands as functions, where applicable (Wait-Response, 
                ConvertFrom-CliXml,Test-Port)
                -Updated help topics
                -Added -ImpersonationLevel parameter to allow wider choice of impersonation types
                as well as supporting remote issued commands that will not work when using impersonation
                -Checks to see if using impersonation and handle accordingly
                -Added additional error handling
            Version 1.0 -- 22 Feb 2014
                -Initial Version
#>
#region Private Functions
Function Wait-Response {
    $stringBuilder = New-Object Text.StringBuilder 
    $Waiting = $True
    While ($Waiting) {
        While ($TcpClient.available -gt 0) {
            Write-Verbose "Processing return bytes: $($TcpClient.Available)"
            #$clientstream = $TcpClient.GetStream()
            [byte[]]$inStream = New-Object byte[] $TcpClient.Available
            $buffSize = $TcpClient.Available
            $return = $NegotiateStream.Read($inStream, 0, $buffSize)
            [void]$stringBuilder.Append([System.Text.Encoding]::ASCII.GetString($inStream[0..($return-1)]))
            Start-Sleep -Seconds 1
        }
        If ($stringBuilder.length -gt 0) {
            #$stringBuilder.ToSTring() | ConvertFrom-CliXml
            $returnedData = [System.Management.Automation.PSSerializer]::DeSerialize($stringBuilder.ToString())
            Remove-Variable String -ErrorAction SilentlyContinue
            $Waiting = $False
        }
        #[void]$stringBuilder.Clear()
    }
    #Return data
    Write-Output $returnedData    
}
Function ConvertFrom-CliXml {
    #Function borrowed from Joel Bennett (http://poshcode.org/4545) 
    #Original Author David Sjstrand (http://poshcode.org/2294)
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$InputObject
    )
    begin
    {
        $OFS = "`n"
        [String]$xmlString = ""
    }
    process
    {
        $xmlString += $InputObject
    }
    end
    {
        $type = [PSObject].Assembly.GetType('System.Management.Automation.Deserializer')
        $ctor = $type.GetConstructor('instance,nonpublic', $null, @([xml.xmlreader]), $null)
        $sr = New-Object System.IO.StringReader $xmlString
        $xr = New-Object System.Xml.XmlTextReader $sr
        $deserializer = $ctor.Invoke($xr)
        $done = $type.GetMethod('Done', [System.Reflection.BindingFlags]'nonpublic,instance')
        while (!$type.InvokeMember("Done", "InvokeMethod,NonPublic,Instance", $null, $deserializer, @()))
        {
            try {
                $type.InvokeMember("Deserialize", "InvokeMethod,NonPublic,Instance", $null, $deserializer, @())
 
            } catch {
                Write-Warning "Could not deserialize ${string}: $_"
            }
        }
        $xr.Close()
        $sr.Dispose()
    }
}
Function Test-Port {
    Param (
        $Computername,
        $Port
    )
    $tcpClient = New-Object System.Net.Sockets.TCPClient
    $Error.Clear()
    $connect = $tcpClient.BeginConnect($Computername,$Port,$null,$null) 
    $wait = $connect.AsyncWaitHandle.WaitOne(1000,$false) 
    If(-Not $wait) {
        $False
    } Else {
        $tcpClient.GetStream().Write(4,0,1)
        [void]$tcpClient.EndConnect($connect)
        If ($Error) {
            $False
        } Else {
            $True
        }
    }
    $tcpClient.Close() 
}
#endregion Private Functions

#region Public Functions
Function Invoke-TCPServer {
    <#
        .SYNOPSIS
            Starts a TCP Server on a local or remote system. Used to send commands to server
            that will be run and returns data to client. Use Send-Command with -Command 'Exit'
            to shut down TCP Server.

        .DESCRIPTION
            Starts a TCP Server on a local or remote system. Used to send commands to server
            that will be run and returns data to client.Use Send-Command with -Command 'Exit'
            to shut down TCP Server.

        .PARAMETER Computername
            Computer to start TCP server on

        .PARAMETER Port
            Port that TCP server will be listening on

        .PARAMETER Credential
            Supply alternate credentials to start the server with

        .PARAMETER ImpersonationLevel
            Specific Impersonation level to use with connection.

            Default is: Impersonation

            Possible Values:

            Delegation
            Identification
            Impersonation
            None

            If set to 'None', then no impersonation will occur.

        .NOTES
            Name: Invoke-TCPServer
            Author: Boe Prox
            DateCreated: 22 Feb 2014
            Version History:
                Version 1.1 -- 24 Feb 2014
                    -Added -ImpersonationLevel which will allow for a specific level of impersonation or no
                    impersonation at all.
                    -Updated error handling
                    -Broke out commonly used commands as Private functions (Test-Port)
                Version 1.0 -- 22 Feb 2014
                    -Initial Version

        .EXAMPLE
            Invoke-TCPServer -Computername 'Server' -Port 1655

            Computername         : Server
            Port                 : 1655
            ProcessID            : 1940
            ProcessCreationState : Successful
            IsPortAvailable      : True

            Description
            -----------
            Starts a TCP Server on Server listening on port 1655. Object returned shows the processID,
            Computername as well as if the port can be reached (may be removed as it isn't completely accurate sometimes).

        .EXAMPLE
            Invoke-TCPServer -Computername 'Server' -Port 1655 -Credential 'domain\administrator'

            Computername         : Server
            Port                 : 1655
            ProcessID            : 2596
            ProcessCreationState : Successful
            IsPortAvailable      : True

            Description
            -----------
            Starts a TCP Server on Server listening on port 1655. Object returned shows the processID,
            Computername as well as if the port can be reached (may be removed as it isn't completely accurate sometimes).
            This is started using the supplied credentials: domain\Administrator.
    #>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string[]]$Computername = $env:COMPUTERNAME,
        [parameter()]
        [int]$Port = 1655,
        [parameter()]
        [Alias('RunAs')]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        [parameter()]
        [ValidateSet('Impersonation','Delegation','Identification','None')]
        [System.Security.Principal.TokenImpersonationLevel]$ImpersonationLevel = 'Impersonation' 
    )
    Begin {   
        Write-Verbose ("PSCommandPath $PSCommandPath")
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose $_
        }         
        #region WMI Parameters
        $WMIParams = @{
            Class = 'Win32_Process'
            Name = 'Create'
            ErrorAction = 'Stop'
        }
        If ($PSBoundParameters['Credential']) {
            $WMIParams.Credential = $Credential
        }
        #endregion WMI Parameters
        If ($ImpersonationLevel -eq 'None') {
            Write-Verbose "Changing ImpersonationLevel to Identification"
            $ImpersonationLevel = 'Identification'
            $DoNotImpersonate = $True
        } Else {
            $DoNotImpersonate = $False
        }        
    }
    Process {
        ForEach ($Computer in $Computername) {
            $WMIParams.Computername = $Computer
            Write-Verbose "Assiging values to code block"
            $Command = @'
                $VerbosePreference = 'Continue'
                $Computername = "{0}"
                $Port = {1}
                $ImpersonationLevel = "{2}"
                $DoNotImpersonate = [bool]::Parse("{3}")
                #region helper functions
                function ConvertTo-CliXml $[
                    #Function borrowed from Joel Bennett (http://poshcode.org/4544)
                    #Original Author Oisin Grehan (http://poshcode.org/1672)
                    param(
                        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
                        [ValidateNotNullOrEmpty()]
                        [PSObject[]]$InputObject
                    )
                    begin $[
                        $type = [PSObject].Assembly.GetType('System.Management.Automation.Serializer')
                        $ctor = $type.GetConstructor('instance,nonpublic', $null, @([System.Xml.XmlWriter]), $null)
                        $sw = New-Object System.IO.StringWriter
                        $xw = New-Object System.Xml.XmlTextWriter $sw
                        $serializer = $ctor.Invoke($xw)
                        #$method = $type.GetMethod('Serialize', 'nonpublic,instance', $null, [type[]]@([object]), $null)
                    $]
                    process $[
                        try $[
                            [void]$type.InvokeMember("Serialize", "InvokeMethod,NonPublic,Instance", $null, $serializer, [object[]]@($InputObject))

                        $] catch $[
                            Write-Warning "Could not serialize $($InputObject.GetType()): $_"
                        $]
                    $]
                    end $[    
                        [void]$type.InvokeMember("Done", "InvokeMethod,NonPublic,Instance", $null, $serializer, @())
                        $sw.ToString()
                        $xw.Close()
                        $sw.Dispose()
                    $]
                $]
                Function Test-IsAdmin $[
                    Param (
                        [Security.Principal.WindowsIdentity]$Identity
                    )
                    ([Security.Principal.WindowsPrincipal]$Identity).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
                $]
                Function Send-Response $[
                    [cmdletbinding()]
                    Param (
                        $Response
                    )
                    Try $[
                        Write-Verbose "Serializing data before sending using PSSerializer"
                        $ErrorActionPreference = 'stop'
                        $serialized = [System.Management.Automation.PSSerializer]::Serialize($Response)
                    $] Catch $[
                    Write-Verbose "Serializing data before sending using ConvertTo-CliXml"
                        $serialized = $Response | ConvertTo-CliXml

                    $] 
                    $ErrorActionPreference = 'Continue'
                    #Resend the Data back to the client
                    $bytes  = [text.Encoding]::Ascii.GetBytes($serialized)
                    $string = $Null

                    #Send the data back to the client
                    Write-Verbose "Echoing $($bytes.count) bytes to $remoteClient"
                    $NegotiateStream.Write($bytes,0,$bytes.length)
                    $NegotiateStream.Flush()
                $]
                #endregion helper functions
                [console]::Title = "TCP Server <$Computername | $Port | $ImpersonationLevel | DoNotImpersonate: $DoNotImpersonate>"
                #Create the Listener port 
                $Listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $Port

                #Start the listener; opens up port for incoming connections
                $Listener.Start()
                Write-Verbose "Server started on port $Port"
                $Active = $True
                $OriginalPath = $Pwd
                While ($Active) $[
                    $incomingClient = $Listener.AcceptTcpClient()
                    $remoteClient = $incomingClient.client.RemoteEndPoint.Address.IPAddressToString
                    Write-Verbose ("New connection from $remoteClient")
                    #Let it buffer for a second
                    Start-Sleep -Milliseconds 1000

                    #Get the data stream from connected client
                    $stream = $incomingClient.GetStream()
                    $NegotiateStream =  New-Object net.security.NegotiateStream -ArgumentList $stream
                    #Validate default credentials
                    Try $[
                        Write-Verbose "Waiting to authenticate client"
                        $NegotiateStream.AuthenticateAsServer(
                            [System.Net.CredentialCache]::DefaultNetworkCredentials,
                            [System.Net.Security.ProtectionLevel]::EncryptAndSign,
                            [System.Security.Principal.TokenImpersonationLevel]::$ImpersonationLevel                        
                        )
                        Write-Verbose "$($incomingClient.client.RemoteEndPoint.Address) Authenticated as $($NegotiateStream.RemoteIdentity.Name) via $($NegotiateStream.RemoteIdentity.AuthenticationType)"
                        Write-Verbose "Currently: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
                        If ($DoNotImpersonate) $[
                            Write-Verbose "Verifing Administrator access for $($NegotiateStream.RemoteIdentity.Name)"
                            If (Test-IsAdmin $NegotiateStream.RemoteIdentity) $[
                                Write-Verbose "$($NegotiateStream.RemoteIdentity.Name): Allowed Access"
                                Write-Verbose "Sending authentication response"
                                Send-Response "Good"
                            $] Else $[
                                Throw "Access Denied for $($NegotiateStream.RemoteIdentity.Name)"
                            $]
                        $] Else $[
                            Write-Verbose "Attempting to impersonate"                        
                            $remoteUserToken = $NegotiateStream.RemoteIdentity.Impersonate()
                            Write-Verbose "Impersonating as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
                            Write-Verbose "Sending authentication response"
                            Send-Response "Good"
                        $]
                        $activeConnection = $True       
                        $stringBuilder = New-Object Text.StringBuilder
                        While ($incomingClient.Connected) $[    
                            #Is there data available to process
                            If ($Stream.DataAvailable) $[
                                Do $[
                                    [byte[]]$byte = New-Object byte[] 1024
                                    Write-Verbose "$($incomingClient.Available) Bytes available from $($remoteClient)"
                                    $bytesReceived = $NegotiateStream.Read($byte, 0, $byte.Length)
                                    If ($bytesReceived -gt 0) $[
                                        Write-Verbose "$bytesReceived Bytes received from $remoteClient"
                                        [void]$stringBuilder.Append([text.Encoding]::Ascii.GetString($byte[0..($bytesReceived - 1)]))
                                    $] Else $[
                                        $activeConnection = $False
                                        Break
                                    $]   
                                $] While ($Stream.DataAvailable)
                                $string = $stringBuilder.ToString()
                                If ($stringBuilder.Length -gt 0) $[
                                    If ($string -match '^(Quit|Exit)') $[                                        
                                        Write-Verbose "Message received from $($remoteClient):`n$($stringBuilder.ToString())"
                                        Write-Verbose 'Shutting down...'
                                        $data = "Shutting down TCP Server on $Computername <$Port>"
                                        Send-Response -Response $data
                                        $Active = $False
                                        $NegotiateStream.Close()
                                        $Listener.Stop()
                                    $] Else $[
                                        Write-Verbose "Message received from $($remoteClient):`n$string"
                                        Try $[       
                                            $ErrorActionPreference = 'Stop'    
                                            Write-Verbose "Running command"        
                                            $Data = [scriptblock]::Create($string).Invoke()
                                        $] Catch $[
                                            $Data = $_.Exception.Message
                                        $]
                                        If (-Not $DoNotImpersonate) $[
                                            Write-Verbose "Undoing impersonation"
                                            $remoteUserToken.Undo()
                                            $remoteUserToken.Dispose()
                                        $]
                                        If (-Not $Data) $[
                                            $Data = 'No data to return!'
                                        $]
                                        Send-Response -Response $Data
                                    $]                
                                $] Else $[
                                    If (-Not $DoNotImpersonate) $[
                                        Write-Verbose "Undoing impersonation"
                                        $remoteUserToken.Undo()
                                        $remoteUserToken.Dispose()
                                    $]
                                    Send-Response -Response 'No data'
                                $]
                                Write-Verbose "Closing session to $remoteClient"
                                $incomingClient.Close()
                            $]
                            Start-Sleep -Milliseconds 1000
                        $]
                    $] Catch $[
                        Write-Warning $_.Exception.Message
                        Try $[
                            Send-Response -Response $_ -ErrorAction Stop
                        $] Catch $[
                            Write-Warning $_.Exception.Message
                        $]
                        $NegotiateStream.Dispose()
                        $incomingClient.Close()
                        $incomingClient.Dispose()
                        Continue
                    $]
                    [void]$stringBuilder.Clear()
                $]
'@ -f $Computer,$Port,$ImpersonationLevel,$DoNotImpersonate -replace '\$\[','{' -replace '\$\]','}'
            $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
            $encodedCommand = [Convert]::ToBase64String($bytes)
            If ($Computername -eq $env:COMPUTERNAME) {
            $process = Start-Process -FilePath  "powershell.exe" -ArgumentList  "-noprofile -nologo -encodedcommand $encodedcommand" -PassThru
                Start-Sleep -Seconds 2
                $portcheck = (Test-Port -Computername $Computer -Port $Port)
                [pscustomobject]@{
                    Computername = $Computer
                    Port = $Port
                    ProcessID = $process.ID
                    ProcessCreationState = Switch ($return.ReturnValue) {
                            0 {'Success'}
                            2 {'AccessDenied'}
                            3 {'InsufficientPrivilege'}
                            8 {'UnknownFailure'}
                            9 {'PathNotFound'}
                            21 {'InvalidParameter'}
                        }
                    IsPortAvailable = $portcheck
                }
                Write-Verbose "Use Send-Command with -Command 'Exit' to stop TCP Server"
            } Else {
                $WMIParams.ArgumentList = "powershell.exe -noprofile -nologo -encodedcommand $encodedcommand"
                Write-Verbose "Attempting to start TCP Server on $Computer"
                Try {
                    $return = Invoke-WmiMethod @WMIParams
                    Start-Sleep -Seconds 2
                    $portcheck = (Test-Port -Computername $Computer -Port $Port)
                    [pscustomobject]@{
                        Computername = $Computer
                        Port = $Port
                        ProcessID = $return.ProcessID
                        ProcessCreationState = Switch ($return.ReturnValue) {
                                0 {'Success'}
                                2 {'AccessDenied'}
                                3 {'InsufficientPrivilege'}
                                8 {'UnknownFailure'}
                                9 {'PathNotFound'}
                                21 {'InvalidParameter'}
                            }
                        IsPortAvailable = $portcheck
                    }
                } Catch {                
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
    End {}
}
Function Send-Command {
    <#
        .SYNOPSIS
            Used to send PowerShell commands to a remote listener. Use this command with -Command Exit
            to shut down TCP Server.

        .DESCRIPTION
            Used to send PowerShell commands to a remote listener. Waits for a return response
            and presents data returned from remote system. Use this command with -Command Exit
            to shut down TCP Server.

        .PARAMETER Computername
            Computer to send command to

        .PARAMETER Port
            Remote port to target command on system running TCP Server

        .PARAMETER Credential
            Supply alternate credentials

        .PARAMETER SourcePort
            Use a different source port for endpoint

        .PARAMETER Command
            Command to send to the TCP Server. Recommonded to be contained using single quotes if not
            using a variable containing the commands.

        .PARAMETER ImpersonationLevel
            Specific Impersonation level to use with connection.

            Default is: Impersonation

            Possible Values:

            Delegation
            Identification
            Impersonation
            None

            If set to 'None', then no impersonation will occur.

        .NOTES
            Name: Send-Command
            Author: Boe Prox
            DateCreated: 22 Feb 2014
            Version History:
                Version 1.1 -- 24 Feb 2014
                    -Added -ImpersonationLevel which will allow for a specific level of impersonation or no
                    impersonation at all.
                    -Broke out commonly used commands into Private functions (ConvertFrom-CliXml,Wait-Response)
                    -Changed SourePort default value to a randomized port in case command needs to run again to avoid
                    duplicate endpoint issues when source port is in a TIME_WAIT state
                Version 1.0 -- 22 Feb 2014
                    -Initial Version

        .EXAMPLE
            Send-Command -Computername 'Server' -Port 2656 -Command 'Get-Process | Select -First 1'

            Description
            -----------
            Sends a Get-Process command to Server on port 2656 and returns the first process.

        .EXAMPLE
            Send-Command -Computername 'Server' -Port 2656 -Command 'Get-Service | Select -First 1' -Credential 'domain\proxb'

            Description
            -----------
            Sends command to Server on port 2656 for first service running as domain\proxb
    #>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string]$Computername = $env:COMPUTERNAME,
        [parameter()]
        [int]$Port = 1655,
        [parameter()]
        [Alias('RunAs')]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty, 
        [parameter()]
        [int]$SourcePort=(Get-Random -Minimum 1500 -Maximum 16000),
        [parameter(Mandatory=$True)]
        [string]$Command = 'Exit',
        [parameter()]
        [ValidateSet('Impersonation','Delegation','Identification','None')]
        [System.Security.Principal.TokenImpersonationLevel]$ImpersonationLevel = 'Impersonation'
    )
    Begin {
        Write-Verbose ("PSCommandPath $PSCommandPath")
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose $_
        }
        Try {
            Write-Verbose "Creating Endpoint <$SourcePort> on $env:COMPUTERNAME"
            $Endpoint = new-object System.Net.IPEndpoint ([ipaddress]::any,$SourcePort) 
            $TcpClient = [Net.Sockets.TCPClient]$endpoint
        } Catch {
            Write-Warning $_.Exception.Message
            Break
        }
        If ($ImpersonationLevel -eq 'None') {
            Write-Verbose "Changing ImpersonationLevel to Identification"
            $ImpersonationLevel = 'Identification'
        }
    }
    Process {
        Try {
            Write-Verbose "Initiating connection to $Computername <$Port>"
            $TcpClient.Connect($Computername,$Port)
            $ServerStream = $TcpClient.GetStream()
            $NegotiateStream =  New-Object net.security.NegotiateStream -ArgumentList $ServerStream        

            #Make the recieve buffer a little larger 
            $TcpClient.ReceiveBufferSize = 1MB 
            ##Client 
            Try {            
                If ($PSBoundParameters['Credential']) {
                    Write-Verbose "Attempting authentication to remote system using provided credentials"
                    $NegotiateStream.AuthenticateAsClient(
                        $Credential.GetNetworkCredential(),
                        "MYSERVICE\$env:Computername",
                        [System.Net.Security.ProtectionLevel]::EncryptAndSign,
                        [System.Security.Principal.TokenImpersonationLevel]::$ImpersonationLevel
                    )
                } Else {
                    Write-Verbose "Attempting authentication to remote system using default credentials"
                    $NegotiateStream.AuthenticateAsClient(
                        [System.Net.CredentialCache]::DefaultNetworkCredentials,
                        "MYSERVICE\$env:Computername",
                        [System.Net.Security.ProtectionLevel]::EncryptAndSign,
                        [System.Security.Principal.TokenImpersonationLevel]::$ImpersonationLevel
                    )
                }
                Write-Verbose "Waiting for negotiation response"
                Switch (Wait-Response) {
                    'Good' {
                        Write-Verbose "Passed authentication"
                    }
                    Default {
                        Write-Output $_
                        Throw $_
                    }
                }
                Write-Verbose "Sending command"
                $data = [text.Encoding]::Ascii.GetBytes($Command)
                Write-Verbose "Sending $($data.count) bytes to $Computername <$port>"
                $NegotiateStream.Write($data,0,$data.length)
                $NegotiateStream.Flush()
                Wait-Response
            } Catch {
                Write-Warning $_.Exception.Message
            }
        } Catch {
            Write-Warning $_.Exception.Message
        } 
    }
    End {
        Write-Verbose 'Closing connection'
        If ($NegotiateStream) {$NegotiateStream.Dispose()}
        If ($ServerStream) {$ServerStream.Dispose()}
        If ($TcpClient) {$TcpClient.Dispose()}
    }
}
#endregion Public Functions

#region Aliases
New-Alias -Name scmd -Value Send-Command
New-Alias -Name itcps -Value Invoke-TCPServer
#endregion Aliases

#region Export Module Members
Export-ModuleMember -Function 'Send-Command','Invoke-TCPServer'
Export-ModuleMember -Alias 'scmd','itcps'
#endregion Export Module Members