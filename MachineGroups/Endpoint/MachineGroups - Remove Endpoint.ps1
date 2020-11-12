# MachineGroup - Remove Endpoint
# for Ivanti Security Controls
# version 2020-11.12
#
# Changelog:
# Aug 2019 - Update script to make better use of API and work with more than 50 machines in a group.
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$MachineGroupName = "$[MachineGroup name]"
$MachineName = "$[Machine name]"
$MachineGroupID = "$[MachineGroup ID]"


#System variables
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$MachineID = ''
$output = ''


## Part 1: Find ID of Machinegroup

# Only do this when machinegroupid is not given.

if (-not $MachineGroupID) 
{
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?name=' + $MachineGroupName

  #Speak to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetMachinegroupID)'
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
    exit (404)
  }
} #end search for machinegroupid


## Part 2: Find MachineID
$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$WhereAreWe = 0
$found = '0'

while ($finished -eq 0) 
{
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+ $MachineGroupID + '/discoveryFilters?count=50&start='+$start

  #Speak to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (FindMachineID)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(2)
  }

  #REST API was OK. Go futher
  $result = ConvertFrom-Json -InputObject $result
  $WhereAreWe = $result.count

  #Search machinenameid
  for ($count = 0;$count -lt ($result.count); $count++) 
  {
    if ($result.value[$count].name -eq $MachineName) 
    {
      #Machine found
      $found = '1'
      Write-Host -Object 'Machine found in machinegroup'
      $MachineID = $result.value[$count].id
    }
  }
  $sorted = $result.value | Sort-Object  -Property id -Descending   #sort ID to get highest ID
  if ($WhereAreWe -ne 0) 
  {
    $start = ($sorted[0].id) + 1 
  } #change start to highest ID
  if ($WhereAreWe -lt 50) 
  {
    $finished = 1 
  }
  if ($found -eq 1) 
  {
    $finished = 1 
  }
}
if ($found -eq 0) 
{
  #no match found
  Write-Host -Object 'Error: Machine not found in machinegroup'
  exit (2)
} #end search for machinegroupid

## Part 3: Delete machine from Machinegroup
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+ $MachineGroupID + '/discoveryFilters/' + $MachineID

#Speak to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Delete -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (DeleteMachineFromGroup)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(3)
}

#REST API was OK. Go futher
Write-Host -Object 'Deleted OK'
