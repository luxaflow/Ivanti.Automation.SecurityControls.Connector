# Credentials - List
# for Ivanti Security Controls
# version 2020-11.12
#
# Changelog
# Aug 2019 - Update listlimit to 50 (was 10) Nobody should have more than 50 credentials.. right?
# Nov 2019 - Update to use Session Credentials
# 2020-11: update for use of encrypted passwords
# 
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber
$IIDoutput = "$[Output type]" #IID Output or List output

#System variables
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''
$SetSessionCredentials = $True #Can we use SessionCredentials?

######################################################################################################################################
## SessionCredentials initiation

#Check if ISeC 2019.3 is installed so we can use SessionCredentials (by using request Linux metadata)
$url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/productlevelgroups'
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  if ($_.Exception.Response.StatusCode.value__ -ne '404') 
  {
    Write-Host -Object 'Error (ISeC 2019.3 check)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }
  else 
  {
    # 404 error: so ISeC API version lower than 2019.3 or wrong webserver
    $SetSessionCredentials = $False
  }
}

# Go forward if SessionCredentials can be set
If ($SetSessionCredentials) 
{ 
  $isPS2 = $PSVersionTable.PSVersion.Major -eq 2
  if($isPS2)
  {
    [void][Reflection.Assembly]::LoadWithPartialName('System.Security')
  }
  else
  {
    Add-Type -AssemblyName 'System.Security' > $null
  }

  #encrypts an array of bytes using RSA and the console certificate
  function Encrypt-RSAConsoleCert
  {
    param
    (
      [Parameter(Mandatory = $True, Position = 0)]
      [Byte[]]$ToEncrypt
    )
    try
    {
      $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/configuration/certificate'
      $certResponse = Invoke-RestMethod -Uri $url -Method Get -Credential $cred
      [Byte[]] $rawBytes = ([Convert]::FromBase64String($certResponse.derEncoded))
      $cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$rawBytes)
      $rsaPublicKey = $cert.PublicKey.Key
      $encryptedKey = $rsaPublicKey.Encrypt($ToEncrypt, $True)
      return $encryptedKey
    }
    finally
    {
      $cert.Dispose()
    }
  }

  # creates the body for creating credentials 
  $FriendlyName = 'encrypted'
  $body = @{
    'userName' = $username
    'name'   = $FriendlyName
  }
  $bstr = [IntPtr]::Zero
  try
  {
    # Create an AES 128 Session key.
    $algorithm = [System.Security.Cryptography.Xml.EncryptedXml]::XmlEncAES128Url
    $aes = [System.Security.Cryptography.SymmetricAlgorithm]::Create($algorithm)
    $keyBytes = $aes.Key
    # Encrypt the session key with the console cert
    $encryptedKey = Encrypt-RSAConsoleCert -ToEncrypt $keyBytes
    $session = @{
      'algorithmIdentifier' = $algorithm
      'encryptedKey'      = [Convert]::ToBase64String($encryptedKey)
      'iv'                = [Convert]::ToBase64String($aes.IV)
    }
    # Encrypt the password with the Session key.
    $cryptoTransform = $aes.CreateEncryptor()
    # Copy the BSTR contents to a byte array, excluding the trailing string terminator.
    $size = [System.Text.Encoding]::Unicode.GetMaxByteCount($EncryptPassword.Length - 1)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptPassword)
    $clearTextPasswordArray = New-Object -TypeName Byte[] -ArgumentList $size
    [System.Runtime.InteropServices.Marshal]::Copy($bstr, $clearTextPasswordArray, 0, $size)
    $cipherText = $cryptoTransform.TransformFinalBlock($clearTextPasswordArray, 0 , $size)
    $passwordJson = @{
      'cipherText'   = $cipherText
      'protectionMode' = 'SessionKey'
      'sessionKey'   = $session
    }
  }
  finally
  {
    # Ensure All sensitive byte arrays are cleared and all crypto keys/handles are disposed.
    if ($clearTextPasswordArray -ne $null) 
    {
      [Array]::Clear($clearTextPasswordArray, 0, $size) 
    }
    if ($keyBytes -ne $null) 
    {
      [Array]::Clear($keyBytes, 0, $keyBytes.Length)
    }
    if ($bstr -ne [IntPtr]::Zero) 
    {
      [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) 
    }
    if ($cryptoTransform -ne $null) 
    {
      $cryptoTransform.Dispose()
    }
    if ($aes -ne $null) 
    {
      $aes.Dispose()
    }
  }
  $body.Add('password', $passwordJson)
  $encryptedRemoteConsoleCredential = $body

  # create session credential
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/sessioncredentials'
  try 
  {
    $sessionCredential = Invoke-RestMethod -Uri $url -Body ($encryptedRemoteConsoleCredential.password | ConvertTo-Json -Depth 20) -Credential $cred -ContentType 'application/json' -Method POST
    if (-not $sessionCredential.created) 
    {
      Write-Host -Object 'Error (SessionCredentialSet)'
      Write-Host -Object 'StatusCode: SesseionCredentials requested, but status Created is False'
      exit(11)
    }
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    # Error 409 can be expected if there is already an SessionCredential active for this user
    if ( $_.Exception.Response.StatusCode.value__ -ne '409') 
    {
      Write-Host -Object 'Error (SessionCredential)'
      Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
      Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
      Write-Host 'Error Message:' $_.ErrorDetails.Message
      exit(10)
    }
  }
}    
#######################################################################################################################################################
#Get Credential list of this user

#Speak to ISeC REST API
try 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/credentials?count=50'
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results

if ($IIDoutput -eq 1) 
{
  for ($count = 0;$count -lt ($result.count); $count++) 
  {
    if ($count -eq ($result.count-1)) 
    {
      $output = $output + $result.value[$count].name +';' + $result.value[$count].id
    }
    else
    {
      $output = $output + $result.value[$count].name +';' + $result.value[$count].id + '|'
    }
  }
  $output
}
#List
if ($IIDoutput -eq 0) 
{
  $result.value |
  Sort-Object -Property name |
  Format-Table -AutoSize -Property name, id
}

#######################################################################################################################################################
# SessionCredentials Ending
if ($sessionCredential.created) 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/sessioncredentials'
  $sessionCredential = Invoke-RestMethod -Uri $url -Credential $cred -Method DELETE 
}
