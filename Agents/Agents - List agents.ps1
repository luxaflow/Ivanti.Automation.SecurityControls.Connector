# Agents - List
# for Ivanti Security Controls
# version 2020-11.12
#
# Change Log
# 2019-12: First version
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#Body variables
$IIDoutput = '$[IIDOutput]'

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

#System variables
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword


######################################################################################################################################
## Get Policies
$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$PolicyList = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

while ($finished -eq 0) 
{
  #Request body
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/policies?count=1000&start='+$start

  #Speak to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetAgentPolicies)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }

  #REST API was OK. Go on
  $result = ConvertFrom-Json -InputObject $result
  $WhereAreWe = $result.count
    
  # put result into array
  for ($count = 0;$count -lt $result.count; $count++) 
  {
    $obj = New-Object -TypeName PSObject -Property @{
      id   = $result.value[$count].id
      name = $result.value[$count].name
    }    
    $null = $PolicyList.Add($obj)
  }

  if ($WhereAreWe -ne 0) 
  {
    $start = $start+ 1000
  } #Next 1000
  if ($WhereAreWe -lt 1000) 
  {
    $finished = 1
  }
}

######################################################################################################################################
## Get Agents

$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$AgentList = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

while ($finished -eq 0) 
{
  #Request body
  $url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/agents?count=1000&start='+$start

  #Speak to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetAgents)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }

  #REST API was OK. Go on
  $result = ConvertFrom-Json -InputObject $result
  $WhereAreWe = $result.count
    
  # put result into array
  for ($count = 0;$count -lt $result.count; $count++) 
  {
    $PolicyName = 'Unknown'
    foreach ($pname in $PolicyList) 
    {
      if ($result.value[$count].reportedPolicyID -eq $pname.id) 
      {
        $PolicyName = $pname.name
      }
    }
        

    $obj = New-Object -TypeName PSObject -Property @{
      name          = $result.value[$count].machinename
      id            = $result.value[$count].agentid
      domain        = $result.value[$count].domain
      isListening   = $result.value[$count].isListening
      lastCheckIn   = $result.value[$count].lastCheckIn
      listeningPort = $result.value[$count].listeningPort
      LastKnownIP   = $result.value[$count].lastKnownIPAddress
      Policy        = $PolicyName
    }    
    $null = $AgentList.Add($obj)
  }

  if ($WhereAreWe -ne 0) 
  {
    $start = $start+ 1000
  } #Next 1000
  if ($WhereAreWe -lt 1000) 
  {
    $finished = 1
  }
}


#Results
if ( $AgentList.count -eq 0 ) 
{
  Write-Host -Object 'Error: Agents not found'
}
else 
{  
  #Agent List  
  #Output Name, Domain, LastCheckin, LastKnownIP, IsListening, ListeningPort, Policy

  if ($IIDoutput -eq '1') 
  {
    $output = ''
    for ($count = 0; $count -le $AgentList.count-1; $count++) 
    {
      if ($count -eq 0) 
      {
        $output = $AgentList[$count].Name +';'+ $AgentList[$count].Domain +';'+ [datetime]$AgentList[$count].lastCheckIn +';'+ $AgentList[$count].LastKnownIP+';'+ $AgentList[$count].isListening+';'+ $AgentList[$count].Listeningport+';'+ $AgentList[$count].Policy
      }
      else 
      {
        $output = $output +'|'+ $AgentList[$count].Name +';'+ $AgentList[$count].Domain +';'+ [datetime]$AgentList[$count].lastCheckIn +';'+ $AgentList[$count].LastKnownIP+';'+ $AgentList[$count].isListening+';'+ $AgentList[$count].Listeningport+';'+ $AgentList[$count].Policy
      }
    }
    $output
  }
  else 
  {
    $AgentList | Format-Table -Property Name, domain, lastCheckIn, LastKnownIP, isListening, ListeningPort, Policy
  }
}
