# Patch Deployment Result Summary
# for Ivanti Security Controls
# version 20190404
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchDeployID]"
$IIDoutput = "$[Output Format]"

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/deployments/'+$ISEC_ID+'/machines'
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword

#Connect to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (ScanResults)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  exit(2)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results
#endpoint;domain;IP Address;Completed Patches;Overall State;Last Updated;errorcode;statusdescription
if ($IIDoutput -eq '1') 
{
  $output = ''
  for ($count = 0; $count -le $result.count-1; $count++) 
  {
    if ($count -eq 0) 
    {
      $output = $result.value[$count].Name +';'+ $result.value[$count].Domain +';'+ $result.value[$count].address +';'+ $result.value[$count].completedPatches +';'+ $result.value[$count].overallState +';'+ [datetime]$result.value[$count].lastUpdated +';'+ $result.value[$count].ErrorNumber +';'+ $result.value[$count].ErrorDescription
    }
    else 
    {
      $output = $output +'|'+ $result.value[$count].Name +';'+ $result.value[$count].Domain +';'+ $result.value[$count].address +';'+ $result.value[$count].completedPatches +';'+ $result.value[$count].overallState +';'+ [datetime]$result.value[$count].lastUpdated +';'+ $result.value[$count].ErrorNumber +';'+ $result.value[$count].ErrorDescription
    }
  }
  $output
}
else 
{
  $result.value | Format-Table -Property name, domain, @{
    L = 'IP Address'
    E = {
      $_.address
    }
  }, @{
    L = 'Completed Patches'
    E = {
      $_.completedPatches
    }
  }, overallState, lastUpdated, errornumber, errordescription -Wrap -AutoSize
}
