# Machines - List
# for Ivanti Security Controls
# version 2020-11
#
# Changelog: 
# 2020-08: First version
# 2020-11: EncryptedPassword added
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = "$[Password]" #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber
$securePW = "$[SecurePW]"

#System variables
$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$MachineList = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

if ($securePW -eq '0') 
{
  $EncryptPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
}
else 
{
  try 
  {
    $EncryptPassword = ConvertTo-SecureString $password -ErrorAction Stop
  }
  catch 
  {
    $ErrorMessage = $_.Exception.Message
    Write-Host -Object $ErrorMessage
    Write-Host -Object 'Error 403: Did you run this task on the same machine which encrypted the password?'
    exit(403)
  }
}
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

while ($finished -eq 0) 
{
  #Request body
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machines?count=50&start='+$start

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
      id            = $result.value[$count].id
      MachineName   = $result.value[$count].name
      Domain        = $result.value[$count].domain
      IPaddress     = $result.value[$count].ipAddress
      AssignedGroup = $result.value[$count].assignedGroup
      ISeCconsole   = $result.value[$count].consoleName
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

#normal output
#id, MachineName, Domain, IPaddress, AssignedGroup, ISeC Console
$MachineList |
Sort-Object -Property name |
Format-Table -AutoSize -Property id, MachineName, Domain, IPaddress, AssignedGroup, ISeCconsole