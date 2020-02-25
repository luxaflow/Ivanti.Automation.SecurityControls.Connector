# Patch Scan - ResultDetailed
# for Ivanti Security Controls
# version 2019-11
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchScanID]"
$IIDoutput = '0'


## Step 1: Get resultID
#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scans/'+$ISEC_ID+'/machines'
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

#Request body

#Connect to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (Get ScanResult)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

$ResultID = $result.value.id

## Step 2: Get ScanPatches
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scans/'+$ISEC_ID+'/machines/'+$ResultID+'/patches'
#Connect to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (Get ScanPatches)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(2)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#display Detailedpatches
$result.value |
Where-Object -FilterScript {
  $_.scanState -eq 'MissingPatch' 
} |
Format-Table -Property kb, productName, patchType, vendorseverity