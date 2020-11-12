# MachineGroup - List Endpoints
# for Ivanti Security Controls
# version 2020-11.12
#
# Changelog:
# Aug 2019: Optimization for large Machinegroups, better use of REST API
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

#System variables
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

#Request body


## First find the ID of the Machinegroup so we can make a call to the REST API to get the machines in it
#Speak to ISeC REST API
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?name=' + $MachineGroupName
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (GetMachineGroupID)'
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
    $id = $result.value[$count].id
  }
}
if ($found -eq 0) 
{
  #no match found
  Write-Host -Object 'Error: Machinegroup not found'
  exit(404)
}


## Now get the machinenames

$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$MachineList = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

while ($finished -eq 0) 
{
  #Speak to ISeC REST API
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+$id+'/discoveryFilters?count=50&start=' + $start
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetMachinenames)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(2)
  }
  $result = ConvertFrom-Json -InputObject $result
  $WhereAreWe = $result.count

  #Scan through machinenames and show them (we are only interested in machinename, not other filters)
  $found = ''
  for ($count = 0;$count -lt $result.count; $count++) 
  {
    if ($result.value[$count].category -eq 'MachineName') 
    { 
      #Filter is machinename
      $null = $MachineList.add($result.value[$count].name)
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
}
#Scan through machinenames and show them (we are only interested in machinename, not other filters)
$found = $MachineList.count
for ($count = 0;$count -lt $MachineList.count; $count++) 
{
  $MachineList[$count]
}
if ($found -eq 0) 
{
  Write-Host -Object 'Error: No machines found'
  exit (2)
}
