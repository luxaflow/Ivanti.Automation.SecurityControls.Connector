# Operations - Wait (PatchScan)
# for Ivanti Security Controls
# version 2020-11.12
# 
# Wait till patchscan is complete
#
# Changelog:
# 2019-01: First version
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = Get-ResParam -Name Username #ISeC Credential Username
$password = Get-ResParam -Name Password #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchScanID]"
$CheckSeconds = "$[Check Interval]"
$Logtime = "$[Logging]"
$IIDoutput = "$[Output Type]"

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/operations/'+$ISEC_ID
$EncryptPassword = $password
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $EncryptPassword
$Running = ''

# We are going to WAIT till the Operation is finished.
# So do a loop till result.status <> Running

do 
{ 
  #Speak to ISeC REST API
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
    $datetime = Get-Date -Format "MM/dd/yyyy HH:MM:ss"
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

}
else 
{
  Write-Host -Object $Running
  exit(2)
}

#Show PatchScan Results (mimic Powershell API)

$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scans/'+$ISEC_ID
try 
{
  $result = Invoke-RestMethod -Method Get -Credential $cred -Uri $Url -ContentType 'application/json' | ConvertTo-Json -Depth 99
}
catch 
{
  # Dig into the exception to get the Response details.
  # Note that value__ is not a typo.
  Write-Host -Object 'Error (ScanResults)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(2)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results
#Mimic powershell API output

# calculate and set elapsed time and add it to the result
[datetime]$starttime = $result.startedon  
[datetime]$endtime = $result.updatedOn
$runtime = New-TimeSpan -Start $starttime -End $endtime
[string]$elapsedtime = [string]$runtime.hours.tostring('00') + ':' + $runtime.Minutes.ToString('00') + ':' + $runtime.Seconds.ToString('00')
$result | Add-Member -Name 'Elapsed Time' -Value $elapsedtime -MemberType NoteProperty

#Output ScanName;Elapsed Time;Expected Machines;Completed Machines;Is Complete
if ($IIDoutput -eq '1') 
{
  $output = $result.name+';'+$result.'Elapsed Time'+';'+$result.expectedResultTotal+';'+$result.receivedResultCount+';'+$result.isComplete
  $output
} else 
{
  $result | Format-Table -Property name, 'Elapsed Time', expectedResultTotal, receivedResultCount, isComplete -Wrap -AutoSize
}
