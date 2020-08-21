# Credentials - List users shared with
# for Ivanti Security Controls 2020.1
# version 2020-8
#
# Changelog
# Aug 2020 - First version
# 
# patrick.kaak@ivanti.com
# @pkaak

#Body variables
$CredentialsName = "$[Credential Friendly Name]"

#User variables
$username = "^[ISeC Serviceaccount Username]" #ISeC Credential Username
$password = "^[ISeC Serviceaccount Password]" #ISeC Credential password
$servername = "^[ISeC Servername]" #ISeC console servername
$serverport = "^[ISeC REST API portnumber]" #ISeC REST API portnumber

#System variables
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $encryptpassword
$output = ""
$SetSessionCredentials = $True #Can we use SessionCredentials?

######################################################################################################################################
## SessionCredentials initiation

# Go forward if SessionCredentials can be set
If ($SetSessionCredentials) { 
    $isPS2 = $PSVersionTable.PSVersion.Major -eq 2
    if($isPS2)
    {
        [void][Reflection.Assembly]::LoadWithPartialName("System.Security") 
    }
    else
    {
        Add-Type -AssemblyName "System.Security" > $null
    }

    #encrypts an array of bytes using RSA and the console certificate
    function Encrypt-RSAConsoleCert
    {
    	param
    	(
		    [Parameter(Mandatory=$True, Position = 0)]
		    [Byte[]]$ToEncrypt
	    )
	    try
	    {
    		$url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/configuration/certificate"
            $certResponse = Invoke-RestMethod $url -Method Get -Credential $cred
		    [Byte[]] $rawBytes = ([Convert]::FromBase64String($certResponse.derEncoded))
		    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$rawBytes)
		    $rsaPublicKey = $cert.PublicKey.Key;
		    $encryptedKey = $rsaPublicKey.Encrypt($ToEncrypt, $True);
		    return $encryptedKey
	    }
	    finally
	    {
    		$cert.Dispose();
    	}
    }

    # creates the body for creating credentials 
        $FriendlyName="encrypted"
	    $body = @{ "userName" = $UserName; "name" = $FriendlyName; }
	    $bstr = [IntPtr]::Zero;
	    try
	    {
    		# Create an AES 128 Session key.
	    	$algorithm = [System.Security.Cryptography.Xml.EncryptedXml]::XmlEncAES128Url
    		$aes = [System.Security.Cryptography.SymmetricAlgorithm]::Create($algorithm);
		    $keyBytes = $aes.Key;
		    # Encrypt the session key with the console cert
		    $encryptedKey = Encrypt-RSAConsoleCert -ToEncrypt $keyBytes
		    $session = @{ "algorithmIdentifier" = $algorithm; "encryptedKey" = [Convert]::ToBase64String($encryptedKey); "iv" = [Convert]::ToBase64String($aes.IV); }
		    # Encrypt the password with the Session key.
		    $cryptoTransform = $aes.CreateEncryptor();
		    # Copy the BSTR contents to a byte array, excluding the trailing string terminator.
		    $size = [System.Text.Encoding]::Unicode.GetMaxByteCount($EncryptPassword.Length - 1);
		    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptPassword)
		    $clearTextPasswordArray = New-Object Byte[] $size
		    [System.Runtime.InteropServices.Marshal]::Copy($bstr, $clearTextPasswordArray, 0, $size)
		    $cipherText = $cryptoTransform.TransformFinalBlock($clearTextPasswordArray, 0 , $size)
		    $passwordJson = @{ "cipherText" = $cipherText; "protectionMode" = "SessionKey"; "sessionKey" = $session }
	    }
	    finally
	    {
    		# Ensure All sensitive byte arrays are cleared and all crypto keys/handles are disposed.
		    if ($clearTextPasswordArray -ne $null) { [Array]::Clear($clearTextPasswordArray, 0, $size) }
		    if ($keyBytes -ne $null) { [Array]::Clear($keyBytes, 0, $keyBytes.Length); }
		    if ($bstr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
		    if ($cryptoTransform -ne $null) { $cryptoTransform.Dispose(); }
		    if ($aes -ne $null) { $aes.Dispose(); }
	    }
	    $body.Add("password", $passwordJson)
	    $encryptedRemoteConsoleCredential = $Body

    # create session credential
    $url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/sessioncredentials"
    try {
            $sessionCredential = Invoke-RestMethod $Url -body ($encryptedRemoteConsoleCredential.password | ConvertTo-Json -Depth 20) -Credential $cred -ContentType 'application/json' -Method POST
                if (-not $SessionCredential.created) {
                Write-Host "Error (SessionCredentialSet)"
                Write-Host "StatusCode: SesseionCredentials requested, but status Created is False"
                exit(11)
    }
        } catch {
            # Dig into the exception to get the Response details.
            # Note that value__ is not a typo.
            # Error 409 can be expected if there is already an SessionCredential active for this user
            if ( $_.Exception.Response.StatusCode.value__ -ne "409") {
                Write-Host "Error (SessionCredential)"
                Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
                Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
                Write-Host "Error Message:" $_.ErrorDetails.Message
                exit(10)
                }
            }
}    
#######################################################################################################################################################
#Get CredentialID
$Url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/credentials?name=" + $credentialsname

#Request body

#Speak to ISeC REST API
try {
   $result = Invoke-RestMethod -Method Get -Credential $cred -URI $Url -ContentType "application/json" | ConvertTo-Json -Depth 99
} catch {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host "Error (GetCredentialsID)"
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Write-Host "Error Message:" $_.ErrorDetails.Message
    exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json $result

#Results
$found = "0"
    if ($result.name -eq $CredentialsName) {
        #Credential found found
        $found = "1"
        $CredentialID = $result.id
        }
if ($found -eq 0) {
    #no match found
    write-host "Error: Credentials not found"
    exit(404)
    }

#Share Credentials
$Url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/credentials/" + $CredentialID + "/share"
$body=""
 
#Connect to ISeC REST API
try {
   $result = Invoke-RestMethod -Method Get -Credential $cred -URI $Url -Body $Body -ContentType "application/json" | ConvertTo-Json -Depth 99
} catch {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host "Error (ShareCredentials)"
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Write-Host "Error Message:" $_.ErrorDetails.Message
    if ($_.Exception.Response.StatusCode.value__ -eq 401){ write-host "Are you the owner of the credentials you try to share?"}
    Exit(3) #Hold on error
}

#REST API was OK. Go on
$result = ConvertFrom-Json $result
$Result.value

#######################################################################################################################################################
# SessionCredentials Ending
if ($sessionCredential.created) {
 $url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/sessioncredentials"
 $sessionCredential = Invoke-RestMethod $Url -Credential $cred -Method DELETE 
}