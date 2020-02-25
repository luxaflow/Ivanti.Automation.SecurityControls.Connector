# Operations - Wait (PatchDeploy)
# for Ivanti Security Controls
# version 2019-01
# 
# Check Operations from ISeC console
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchDeployID]"
$CheckSeconds = "$[Check every x seconds]"
$Logtime = "$[Log datetime and status]"

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/operations/'+$ISEC_ID
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$Running = ''

# We are going to WAIT till the Operation is finished.
# So do a loop till result.status <> Running

do 
{ 
  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType "application/json" | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object "Error (OperationsWait)"
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Write-Host "Error Message:" $_.ErrorDetails.Message
    exit (1)
  }

  #REST API was OK. Go on
  $result = ConvertFrom-Json -InputObject $result
  if ($Logtime -eq "True") 
  { 
    $datetime = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
    Write-Host $datetime $result.status
  }
  $Running = $result.status

  if ($Running -eq "Running") 
  {
    Start-Sleep -Seconds $CheckSeconds # Do not burden the REST API too much if we are still busy scanning
  }
}
until ($Running -ne 'Running')

#We are finished
if ($Running -eq 'Succeeded')  
{
  Write-Host -Object $Running
  exit(0)
}
else 
{
  Write-Host -Object $Running
  exit(2)
}
