# Based upon work from Carlos Perez - https://github.com/darkoperator/

#Initialize
$key = "password12345"
$message = "The Nuclear Launch is a 5:00pm EST"

$enc = [system.Text.Encoding]::UTF8
$MsgBytes = $enc.GetBytes($message)

# Generate a Random Secure Salt
$Salt = New-Object byte[] 32
$RNG = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$RNG.GetBytes($Salt)

# Set parameters
$PBKDF2 = @($Key,$Salt,10000)

# Create object and get key and IV
$EncPBKDF2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes  -ArgumentList $PBKDF2
$KeyBytes  = $EncPBKDF2.GetBytes(32)
$IVBytes   = $EncPBKDF2.GetBytes(16)

# Create CryptoStream to encrypt message with default 128 block size and default 256 Key size
$AesManaged = New-Object Security.Cryptography.AesManaged
$Encryptor = $AesManaged.CreateEncryptor($KeyBytes, $IVBytes)
$MemStream = New-Object IO.MemoryStream
$StreamMode = [System.Security.Cryptography.CryptoStreamMode]::Write
$CryptArgs = @($MemStream, $Encryptor, $StreamMode)
$CrypStr = New-Object Security.Cryptography.CryptoStream -ArgumentList $CryptArgs

# Encrypt string using the Crypto stream
$CrypStr.Write($MsgBytes, 0, $MsgBytes.Length)
$CrypStr.FlushFinalBlock()

# Append salt to the start of the encrypted file
$CipherBytes = $Salt + ($MemStream.ToArray())
$CrypStr.Close()
$MemStream.Close()
$CipherBytes | out-file Encrypted.AES
