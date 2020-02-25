# Patch Scan - Start
# for Ivanti Security Controls
# version 2019-11
# 
# Changelog
# Aug 2019 - Updated for better use of API, search credentialsid changed
# nov 2019 - Update to use SessionCredentials (needs ISeC 2019.3)
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber


$MachineGroupName = "$[MachineGroup name]" #MachineGroup to scan
$MachineGroupID = "$[MachineGroup ID]" #MachineGroupID (leave blank to search for machinegroupname)
$PatchTemplateID = "$[PatchTemplate ID]" #PatchTemplateID (leave blank to search for PatchTempaltename)
$PatchTemplateName = "$[PatchTemplate Name]" #Patch Template to use in scan (leave empty together with PatchtemplateID to use default template)
$CredentialID = "$[Credentials ID]" #CredentialsID (leave blank to search for credentialsname
$CredentialName = "$[Credentials Name]" #Credentialsname to use in scan
$PatchScanDescription = "$[Patch Scan description]" #Name of the Patch Scan to show in GUI
$MachineName = "$[Device name]" #Machinename - when scanning for a machine and not a group
$ScanMachineOrGroup = "$[Scan type]" #Scan a MachineGroup or a Machine

#System variables
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$MachineID = ''
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
### Now start the patch scan

## Part 1: Find Patchtemplate ID

# No templatename or ID? Than revert back to the default "Security Patch Scan" (mimic Powershell API)
if (-not $PatchTemplateID -and (-not $PatchTemplateName)) 
{
  $PatchTemplateName = 'Security Patch Scan'
}

# Search ID if needed
if (-not $PatchTemplateID) 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scanTemplates?name=' + $PatchTemplateName
    
  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetPatchTemplateID)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }

  #REST API was OK. Go on
  $result = ConvertFrom-Json -InputObject $result

  #Results
  $found = '0'
  for ($count = 0;$count -lt ($result.count); $count++) 
  {
    if ($result.value[$count].name -eq $PatchTemplateName) 
    {
      #Patch template found
      $found = '1'
      $PatchTemplateID = $result.value[$count].id
    }
  }
  if ($found -eq 0) 
  {
    #no match found
    Write-Host -Object 'Error: Patch Template not found'
    exit (1)
  }
} # end search for patchtemplateID

## Part 2: Find MachineGroupID if needed
if (-not $MachineGroupID -and $ScanMachineOrGroup -eq 'Group') 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?name=' + $MachineGroupName
    
  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetMachineGroupID)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(2)
  }

  #REST API was OK. Go on
  $result = ConvertFrom-Json -InputObject $result

  #Results
  $found = '0'
  for ($count = 0;$count -lt ($result.count); $count++) 
  {
    if ($result.value[$count].name -eq $MachineGroupName) 
    {
      #Machinegroup found
      $found = '1'
      $MachineGroupID = $result.value[$count].id
    }
  }
  if ($found -eq 0) 
  {
    #no match found
    Write-Host -Object 'Error: Machinegroup not found'
    exit (2)
  }
} #end search for MachineGroupID

## Part 3: Find CredentialsID if needed
if (-not $CredentialID) 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/credentials?name=' + $CredentialName

  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetCredentialsID)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit (3)
  }

  #REST API was OK. Go futher
  $result = ConvertFrom-Json -InputObject $result

  #Results
  $found = '0'
    
  if ($result.name -eq $CredentialName) 
  {
    #Credentials found
    $found = '1'
    $CredentialID = $result.id
  }
        
  if ($found -eq 0) 
  {
    #no match found
    Write-Host -Object 'Error: Credentials not found'
    exit (3)
  }
} #end search for CredentialsID

## Part 4: Invoke the Patch Scan
$patchScanUrl = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scans'

if ($ScanMachineOrGroup -eq 'Group') 
{
  #We are going to scan a MachineGroup
  $patchScanBody = 
  @{
    Machinegroupids   = @($MachineGroupID)
    Name              = $PatchScanDescription
    TemplateId        = $PatchTemplateID
    runAsCredentialId = $CredentialID
  } | ConvertTo-Json -Depth 99
}
else 
{
  #We are going to scan a machine
  $patchScanBody = 
  @{
    EndpointNames     = @($MachineName)
    Name              = $PatchScanDescription
    TemplateId        = $PatchTemplateID
    runAsCredentialId = $CredentialID
  } | ConvertTo-Json -Depth 99
}
#Connect to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Post -Credential $cred -Uri $patchScanUrl -Body $patchScanBody -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (InvokePatchScan)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit (4)
}

$result = ConvertFrom-Json -InputObject $result

#show the ID of the patchscan
$result.id

#######################################################################################################################################################
# SessionCredentials Ending
if ($sessionCredential.created) 
{
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/sessioncredentials'
  $sessionCredential = Invoke-RestMethod -Uri $url -Credential $cred -Method DELETE 
}
