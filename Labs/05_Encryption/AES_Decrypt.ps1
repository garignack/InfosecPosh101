# Based upon work from Carlos Perez - https://github.com/darkoperator/

$CipherBytes = get-content "Encrypted.AES"
$key = "password12345"

# Get the embedded salt and Encrypted bytes
$SaltBytes = $CipherBytes[0..31]
[byte[]]$EncBytes = $CipherBytes[32..$CipherBytes.Length]

# Derive key and IV using the extracted salt and passphrase
$PBKDF2Args = @($key,$SaltBytes,10000)

$DecPBKDF2 =  New-Object System.Security.Cryptography.Rfc2898DeriveBytes  -ArgumentList $PBKDF2 
$DecKeyBytes  = $DecPBKDF2.GetBytes(32)
$DecIVBytes   = $DecPBKDF2.GetBytes(16)

# Create decrypting cipherstream
$AesManaged = New-Object Security.Cryptography.AesManaged
$Decryptor = $AESManaged.CreateDecryptor($DecKeyBytes, $DecIVBytes)
$MemStream = New-Object System.IO.MemoryStream -ArgumentList (,$EncBytes)
$DecStreamMode = [System.Security.Cryptography.CryptoStreamMode]::Read
$DecArgs = @($MemStream, $Decryptor, $DecStreamMode)
$DecCryptoStream = New-Object Security.Cryptography.CryptoStream -ArgumentList $DecArgs

# Decrypt byte array
$buffer = New-Object byte[] ($EncBytes.Length)
$DecCryptoStream.Read($buffer, 0 , $EncBytes.Length) | Out-Null
$DecCryptoStream.Close()
$MemStream.Close()

$message = $enc.GetString($buffer)
write-host $message