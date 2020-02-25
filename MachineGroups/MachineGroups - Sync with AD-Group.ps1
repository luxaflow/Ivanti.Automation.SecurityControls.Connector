# Sync AD-Group to ISeC Machinegroup
# for Ivanti Security Controls
# version 2019-08
#
# Changelog: 
# july 2019 - first version.
# Aug 2019 - Update to make better use of API
#
# patrick.kaak@ivanti.com
# @pkaak

# Requirements: 
# - ISeC trusted root certificated imported on server to run the task
# - Users and Computer (AD) powershell tools should be installed on the server running the task


$ADGroupName = "$[AD-groupname]"
$Machinegroupname = "$[Machinegroupname]"

$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

# Step 1: ## Check if AD Group exists
#####################################
try 
{
  $result = get-adgroup -Identity $ADGroupName
}
catch

[Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{ 
  Write-Host -Object "Error: ADgroup '$ADGroupName' doesn't exist" -ForegroundColor Red
  Exit (1) 
} 
catch 
{ 
  Write-Output -InputObject 'Error: Something else bad happend while checking Active Directory' 
  Exit (1)
} 


# Step 2 ## Check AD Group members and put computermembers into array
#####################################################################
$ComputerInADgroup = [System.Collections.ArrayList]@() # Create array
$members = Get-ADGroupMember -Identity $ADGroupName
foreach ($members in $members)
{
  if ($members.objectClass -eq 'computer') 
  {
    $null = $ComputerInADgroup.Add($members.name) 
  } #Get all computer accounts
}

# Step 3 ## check if machinegroup exists in ISeC and get ID else create machinegroup
####################################################################################
if ( -not $Machinegroupname) 
{
  $Machinegroupname = $ADGroupName 
}
$MachineGroupID = ''

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups?name=' + $Machinegroupname
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$output = ''

#Request body
#Connect to ISeC REST API
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
  $error[0] | Format-List -Force    
  exit(1)
}

#REST API was OK. Go futher
$result = ConvertFrom-Json -InputObject $result

#Results
$found = '0'
for ($count = 0;$count -lt ($result.count); $count++) 
{
  if ($result.value[$count].name -eq $Machinegroupname) 
  {
    #Machinegroup found
    $found = '1'
    $MachineGroupID = $result.value[$count].id
  }
}
if ($found -eq 0) 
{
  #no match found, create machinegroup
  Write-Host 'Machinegroup not found, Creating Machinegroup with the name: ' $Machinegroupname
  $BodyMachineGroupName = $Machinegroupname
  $BodyMachineGroupDescription = "ISeC Active Directory Sync - $Machinegroupname"

  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups'
  $EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
  $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword

  #Request body
  $Body = @{
    name        = $BodyMachineGroupName
    Description = $BodyMachineGroupDescription
  } | ConvertTo-Json -Depth 99

  #Connect to ISeC REST API
  try 
  {
    $result = Invoke-RestMethod -Method Post -Credential $cred -Uri $Url -Body $Body -ContentType 'application/json' | ConvertTo-Json -Depth 99
  }
  catch 
  {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host -Object 'Error (CreateMachineGroup)'
    Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
    Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
    Write-Host 'Error Message:' $_.ErrorDetails.Message
    exit(1)
  }

  #REST API was OK. Go futher
  $result = ConvertFrom-Json -InputObject $result
  $MachineGroupID = $result.id    
}

## Step 4: Extra controle
#########################

# check if there is something to do
if ( ([string]::IsNullOrEmpty($MachineGroupID))) 
{
  Write-Host -Object 'Error: Step 4 Machine group ID is empty or null'
  exit (4)
}
# check if array has machinenames
if ( $ComputerInADgroup.count -eq 0 ) 
{
  Write-Host -Object 'Error: No machines to add'
  exit(4)
}
Write-Host 'MachineGroupID: ' $MachineGroupID

## Step 5: Get all current machines in machinegroup
####################################################
$start = 1 #start ID to get machinegroup list from
$finished = 0 #did we find the end of the list
$ComputerInMachineGroup = [System.Collections.ArrayList]@() # Create array
$WhereAreWe = 0

while ($finished -eq 0) 
{
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+$MachineGroupID+'/discoveryFilters?count=50&start=1'
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
    exit(5)
  }
  $result = ConvertFrom-Json -InputObject $result
  $WhereAreWe = $result.count

  #Scan through machinenames and put them into an array
    
  for ($count = 0;$count -lt $result.count; $count++) 
  {
    if ($result.value[$count].category -eq 'MachineName') 
    { 
      #Filter is machinename
      $null = $ComputerInMachineGroup.Add($result.value[$count].name)
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

## Step 6: Compare arrays
# Compare ComputerInADGroup(a) with ComputerInMachineGroup(b). 
# Machines not in AD but in Machinegroup should be removed from Machinegroup. 
# MAchines not in Machinegroup but in AD should be added to Machinegroup
$ComputerAdd = ''
$ComputerDelete = ''
$ComputerAdd = $ComputerInADgroup | Where-Object -FilterScript {
  $ComputerInMachineGroup -notcontains $_
}
$ComputerDelete = $ComputerInMachineGroup | Where-Object -FilterScript {
  $ComputerInADgroup -notcontains $_
}

## Step 7: Add machines to machinegroup in isec
###############################################    

# check if array has machinenames to add
if ( $ComputerAdd.count -ne 0 ) 
{
  if ($ComputerAdd.count -ne 0) 
  {
    Write-Host 'Added: ' $ComputerAdd 
  }
  # Add machines to machinegroup
  $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+$MachineGroupID+'/discoveryFilters'

  foreach ($ComputerAdd in $ComputerAdd)
  {
    #Request body
    $Body = @{
      discoveryFilters = @(
        @{
          category   = 'MachineName'
          name       = $ComputerAdd
          IsExcluded = $Excluded
      })
    } | ConvertTo-Json -Depth 99

    #Connect to ISeC REST API
    try 
    {
      $result = Invoke-RestMethod -Method Post -Body $Body -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
    }
    catch 
    {
      # Dig into the exception to get the Response details.
      # Note that value__ is not a typo.
      Write-Host -Object 'Error (AddMachineToMachinegroup)'
      Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
      Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
      Write-Host 'Error Message:' $_.ErrorDetails.Message
      exit(7)
    }
  }
}

## Step 8: Delete machines from machinegroup in isec
###############################################    

# check if array has machinenames to delete
if ( $ComputerDelete.count -ne 0 ) 
{
  if ($ComputerDelete.count -ne 0) 
  {
    Write-Host 'Deleted: ' $ComputerDelete 
  } 
  foreach ($ComputerDelete in $ComputerDelete) 
  {
    $start = 1 #start ID to get machinegroup list from
    $finished = 0 #did we find the end of the list
    $MachineList = [System.Collections.ArrayList]@() # Create array
    $WhereAreWe = 0
    $found = '0'

    while ($finished -eq 0) 
    {
      #Find MachineID
      $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+ $MachineGroupID + '/discoveryFilters?count=50&start=' + $start

      #Connect to ISeC REST API
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
        exit(8)
      }

      #REST API was OK. Go futher
      $result = ConvertFrom-Json -InputObject $result
      $WhereAreWe = $result.count

      #Search machinenameid
        
      for ($count = 0;$count -lt ($result.count); $count++) 
      {
        if ($result.value[$count].name -eq $ComputerDelete) 
        {
          #Machine found
          $found = '1'
          $machineid = $result.value[$count].id
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
    } #end of trying to find the machine ( end while )

    if ($found -eq 0) 
    {
      #no match found
      Write-Host -Object 'Error: Machine not found in machinegroup (this should not happened)'
      exit (8)
    } #end search for machinegroupid

    ## Delete machine from Machinegroup
    $Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/machinegroups/'+ $MachineGroupID + '/discoveryFilters/' + $machineid

    #Connect to ISeC REST API
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
      exit(8)
    }

    #REST API was OK. Go futher
  } # next delete
}

Write-Host -Object 'Sync ready'