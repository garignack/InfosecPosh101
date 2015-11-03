function Load-FileCutter {
$Source = @" 
using System;
using System.IO;
using System.Collections.Generic;

namespace PSNessusDB
{ 
    public class Cutter 
    { 
		//Implements Boyd-Moyer-HorsePool Algorithm
		//Adapted from http://aspdotnetcodebook.blogspot.com/2013/04/boyer-moore-search-algorithm.html
		
		public static List<int> SearchBytePattern(byte[] pattern, string FILE_NAME)
        {
			int bufferSize = 65536;
            byte[] needle = pattern;
            if (needle.Length > bufferSize) {bufferSize = needle.Length * 2;}
            byte[] haystack = new byte[bufferSize];
            
            List<int> matches = new List<int>();
            using (FileStream fs = new FileStream(FILE_NAME, FileMode.Open, FileAccess.Read))
            {
                int numBytesToRead = (int)fs.Length;
                if (needle.Length > numBytesToRead)
                {
                        return matches;
                }
                int[] badShift = BuildBadCharTable(needle);

                while (numBytesToRead > 0)
                {
                    int pos = (int)fs.Position;
                    int n = fs.Read(haystack, 0, bufferSize);
                    if (n == 0) { break; }
                    while (needle.Length > n)
                    {
                        byte[] buffer = new byte[bufferSize - n];
                        int o = fs.Read(buffer, 0, buffer.Length);
                        if (o == 0) { break; }
                        haystack.CopyTo(buffer, n);
                        n = n + o;
                    }
                    numBytesToRead = numBytesToRead - n;
                    int offset = 0;
                    int scan = 0;
                    int last = needle.Length - 1;
                    int maxoffset = haystack.Length - needle.Length;
                    while (offset <= maxoffset)
                    {
                        for (scan = last; (needle[scan] == haystack[scan + offset]); scan--)
                        {
                            if (scan == 0)
                            { //Match found
                                int i = pos + offset;
                                if (i <= fs.Length){
                                    matches.Add(i);
                                }
                                offset++;
                                break;
                            }
                        }
                        if (offset + last > haystack.Length - 1) { break; }
                        offset += badShift[(int)haystack[offset + last]];
                    }
                    fs.Position = pos + n - needle.Length;
                }
            }
            return matches;
        }
		
		private static int[] BuildBadCharTable(byte[] needle)
        {
            int[] badShift = new int[256];
            for (int i = 0; i < 256; i++)
            {
                badShift[i] = needle.Length;
            }
            int last = needle.Length - 1;
            for (int i = 0; i < last; i++)
            {
                badShift[(int)needle[i]] = last - i;
            }
            return badShift;
        }
    } 
} 
"@ 
	Add-Type -TypeDefinition $Source -Language CSharp
}

function Get-ByteMatchLocations{
	param(
		[Parameter(Mandatory=$True, HelpMessage="The File to Process")]
		[Alias("f")]
		[ValidateScript({Test-Path $_ })]
		[string]$fileIN,
		[Parameter(Mandatory=$True, HelpMessage="The String to Search For")]
		[Alias("s")]
		[string]$someString,
		[ValidateSet("UTF7","UTF8","UTF32","UNICODE","ASCII", "DEFAULT")] 
        [String]
        $Encoding = "DEFAULT"
	)	
	if($someString){ 
		$enc = [system.Text.Encoding]::$Encoding
		[byte[]] $bytes  = $enc.GetBytes($someString)
	}
    [array] $list = @()
	[array] $list = [PSNessusDB.Cutter]::SearchBytePattern($bytes, $fileIN)
	return $list
}

function Get-FileBytes{
	param(
		[Parameter(Mandatory=$True, HelpMessage="The File to Process")]
		[Alias("f")]
		[ValidateScript({Test-Path $_ })]
		[string]$fileIN,
		[Parameter(Mandatory=$True, HelpMessage="The Starting Byte Location")]
		[int]$startloc,
		[Parameter(Mandatory=$True, HelpMessage="The Ending Byte Location")]
		[int]$endloc
	)
	begin{}
    process{
    $ReadStream = New-Object IO.FileStream($fileIN, [System.IO.FileMode]::Open)
    $WriteStream = New-Object IO.MemoryStream
    
    [int] $maxSize = [int] $ReadStream.Length;
	if (($endloc -eq -1) -or ($endloc -gt $maxSize)){$endloc = $maxSize}
	if ($startloc -lt 0) {$startLoc = 0}
			
	[int] $length = $endloc - $startloc
	[byte[]] $ReadBuffer = new-object byte[] $length
	$ReadStream.Seek($startloc, [System.IO.SeekOrigin]::Begin) | out-null
	
    $bytesleft = $length
    
    do {
        [Int32]$count = $ReadStream.Read($ReadBuffer, 0, $BytesLeft)
        $WriteStream.Write($ReadBuffer, 0, $count)
        $BytesLeft = $BytesLeft - $count
    }
    until ($BytesLeft -eq 0)
    
    [byte[]] $retBytes = $WriteStream.ToArray()
    
    return  $retBytes
    } 
    end{
        $ReadStream.close()
        $ReadStream.Dispose()
       
        $WriteStream.Close()
        $WriteStream.Dispose()
    }   
    
}

function Get-FileString{
	[CmdletBinding()] param(
		[Parameter(Mandatory=$True, HelpMessage="The File to Process")]
		[Alias("f")]
		[ValidateScript({Test-Path $_ })]
		[string]$fileIN,
		[Parameter(Mandatory=$True, HelpMessage="The Starting Byte Location")]
		[int]$startloc,
		[Parameter(Mandatory=$True, HelpMessage="The Ending Byte Location")]
		[int]$endloc,
		[ValidateSet("UTF7","UTF8","UTF32","UNICODE","ASCII", "DEFAULT")] 
        [String]
        $Encoding = "UTF8"
	)
	begin{$enc = [System.Text.Encoding]::$Encoding}
	process{
	$ReadStream = New-Object IO.FileStream($fileIN, [System.IO.FileMode]::Open)
    $WriteStream = New-Object IO.MemoryStream
    
    [int] $maxSize = [int] $ReadStream.Length;
	if (($endloc -eq -1) -or ($endloc -gt $maxSize)){$endloc = $maxSize}
	if ($startloc -lt 0) {$startLoc = 0}
			
	[int] $length = $endloc - $startloc
	[byte[]] $ReadBuffer = new-object byte[] $length
	$ReadStream.Seek($startloc, [System.IO.SeekOrigin]::Begin) | out-null
	
    $bytesleft = $length
    
    do {
        [Int32]$count = $ReadStream.Read($ReadBuffer, 0, $BytesLeft)
        $WriteStream.Write($ReadBuffer, 0, $count)
        $BytesLeft = $BytesLeft - $count
    }
    until ($BytesLeft -eq 0)
    
    [byte[]] $retBytes = $WriteStream.ToArray() 
    $readStream.close()
    $ReadStream.Dispose()
       
    $WriteStream.Close()
    $WriteStream.Dispose()
          
	return $enc.GetString($retBytes)
	}
    end{
        $ReadStream.close()
        $ReadStream.Dispose()
        $WriteStream.Close()
        $WriteStream.Dispose()
    }
    
}

function Convert-BytesToString{
	[CmdletBinding()] param(
		[Parameter(ValueFromPipeline = $True, Mandatory=$True, HelpMessage="Bytes to Convert")]
		[Alias("b")]
		[Byte[]] $bytes,
		
		[ValidateSet("UTF7","UTF8","UTF32","UNICODE","ASCII", "DEFAULT")] 
        [String]
        $Encoding = "ASCII"
	)
	begin{$enc = [System.Text.Encoding]::$Encoding}
	process{return $enc.GetString($bytes)}
	end{}
}
