# MachineGroups - List
# for Ivanti Security Controls
# version 2019-08
#
# Changelog: 
# aug: list all machinegroups (and not only 10)
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber
$IIDoutput = "$[Outputtype]" #IID Output or List output

#System variables
$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$MachineList = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

while ($finished -eq 0) 
{
  #Request body
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?count=50&start='+$start

  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (GetMachineGroups)'
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
      name = $result.value[$count].name
      id   = $result.value[$count].id
    }    
    $null = $MachineList.Add($obj)
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

#Results

if ($IIDoutput -eq 1) 
{
  #Identity Director Output
  #machinegroupname;id
  for ($count = 0;$count -lt ($MachineList.count); $count++) 
  {
    if ($count -eq ($MachineList.count-1)) 
    {
      $output = $output + $MachineList[$count].name +';' + $MachineList[$count].id
    }
    else
    {
      $output = $output + $MachineList[$count].name +';' + $MachineList[$count].id + '|'
    }
  }
  $output
}
#List
if ($IIDoutput -eq 0) 
{
  #normal output
  #machinegroupname id
  $MachineList |
  Sort-Object -Property name |
  Format-Table -AutoSize -Property name, id
}
