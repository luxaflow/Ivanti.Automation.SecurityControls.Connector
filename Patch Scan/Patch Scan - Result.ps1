# Patch Scan - Result
# for Ivanti Security Controls
# version 2020-11.12
#
# Changelog:
# 2019-01: First version
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchScanID]"
$IIDoutput = "$[Output format]"

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scans/'+$ISEC_ID+'/machines'
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

#Request body

#Speak to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (StartPatchScan)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results
#Mimic powershell API output

#Output endpoint;domain;Installed Patches;Missing Patches;Missing SP;Completed on;error number;error description

if ($IIDoutput -eq '1') 
{
  $output = ''
  for ($count = 0; $count -le $result.count-1; $count++) 
  {
    if ($count -eq 0) 
    {
      $output = $result.value[$count].Name +';'+ $result.value[$count].Domain +';'+ $result.value[$count].InstalledPatchCount +';'+ $result.value[$count].MissingPatchCount +';'+ $result.value[$count].MissingServicePackCount +';'+ [datetime]$result.value[$count].CompletedOn +';'+ $result.value[$count].ErrorNumber +';'+ $result.value[$count].ErrorDescription
    }
    else 
    {
      $output = $output +'|'+ $result.value[$count].Name +';'+ $result.value[$count].Domain +';'+ $result.value[$count].InstalledPatchCount +';'+ $result.value[$count].MissingPatchCount +';'+ $result.value[$count].MissingServicePackCount +';'+ [datetime]$result.value[$count].CompletedOn +';'+ $result.value[$count].ErrorNumber +';'+ $result.value[$count].ErrorDescription
    }
  }
  $output
}
else 
{
  $result.value | Format-Table -Property name, domain, @{
    L = 'Installed'
    E = {
      $_.InstalledPatchCount
    }
  }, @{
    L = 'Missing'
    E = {
      $_.missingpatchcount
    }
  }, @{
    L = 'Missing SP'
    E = {
      $_.missingservicepackcount
    }
  }, completedon, errornumber, errordescription -Wrap -AutoSize
}
