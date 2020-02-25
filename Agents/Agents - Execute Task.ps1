# Agents - Execute Task
# for Ivanti Security Controls
# version 2019-12
#
# patrick.kaak@ivanti.com
# @pkaak

#Body variables
$AgentName = '$[Agentname]'
$taskname = '$[Taskname]'

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

#System variables
$EncryptPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword

######################################################################################################################################
## Get AgentID

$url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/agents?name='+$AgentName

#Connect to ISeC REST API

try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (GetAgentID)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}
  
#REST API was OK. Go futher
$result = ConvertFrom-Json -InputObject $result

#Results
if ( $result.count -ne 1 ) 
{
  Write-Host -Object 'Error: Agent not found'
  exit(2)
}
else 
{
  $AgentID = $result.value.AgentID #Set AgentID to Automation
} 

######################################################################################################################################
## Get Agent TasksID

$url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/agenttasks/'+$AgentID+'/tasks'

#Connect to ISeC REST API

try 
{
  $result = Invoke-RestMethod -Method GET -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (GetAgentTasks)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}

$result = ConvertFrom-Json -InputObject $result
  
#Results
$found = 0 #did we find the task?
$taskid = ''
for ($count = 0; $count -le $result.value.count-1; $count++) 
{
  if ( $result.value[$count].taskName -eq $taskname) 
  {
    $found = 1
    $taskid = $result.value[$count].taskid
  }
}
if ($found -eq 0) 
{
  Write-Host -Object 'Error: Task not found'
  Write-Host -Object 'Possible tasks for this agent are:'
  $result.value | Format-Table -Property taskName
  exit(1)
}
else 
{
  #set task to agent
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/agenttasks/'+$AgentID+'/tasks/'+$taskid
  
  try 
  {
    $result = Invoke-RestMethod -Method POST -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (SetAgentTasks)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }

  $result = ConvertFrom-Json -InputObject $result
}
$result.executingTaskId