# Agent Deployment Status
# for Ivanti Security Controls
# version 2019-12
#
# Changelog:
# Dec 2019 - First Version
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$DeploymentID = '$[DeploymentID]'
$iidoutput = '$[Output in Identity Director format]'

#System variables
$EncryptPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$SetSessionCredentials = $True #Can we use SessionCredentials?


#######################################################################################################################################################
## Get CredentialID

$url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/agents/deployment/' + $DeploymentID

#Connect to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (CredentialsID)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit (2)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results
#agentname,percentcomplete, status,statustime
if ($iidoutput -eq '1') 
{
  $output = ''
  for ($count = 0; $count -le $result.agentstatuses.count-1; $count++) 
  {
    if ($count -eq 0) 
    {
      $output = $result.agentstatuses[$count].Name +';'+ $result.agentstatuses[$count].percentComplete +';'+ $result.agentstatuses[$count].status +';'+ [datetime]$result.agentstatuses[$count].statustime
    }
    else 
    {
      $output = $output +'|'+ $result.agentstatuses[$count].Name +';'+ $result.agentstatuses[$count].percentComplete +';'+ $result.agentstatuses[$count].status +';'+ [datetime]$result.agentstatuses[$count].statustime
    }
  }
  $output
}
else 
{
  $result.agentStatuses
}
