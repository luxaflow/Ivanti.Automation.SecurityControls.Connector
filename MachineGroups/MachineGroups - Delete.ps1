# Machinegroups - Delete
# for Ivanti Security Controls
# version 2020-11.12
#
# Changelog:
# Aug 2019 - Better find of Machinegroup ID, better use of API
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$MachineGroupName = "$[Machinegroup Name]"
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
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?name='+ $MachineGroupName

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

  #REST API was OK. Go futher
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
    exit (1)
  }
} #end search for machinegroupid


## Part 2: Delete Machinegroup
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+ $MachineGroupID

#Speak to ISeC REST API
try 
{
  $result = Invoke-RestMethod -Method Delete -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (DeleteMachineGroup)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(2)
}

#REST API was OK. Go futher
$result = ConvertFrom-Json -InputObject $result
Write-Host -Object 'OK'
