# Patch Deployment Result Summary
# for Ivanti Security Controls
# version 2020-11
#
# Changelog:
# 2019-01: first version
# 2020-11: update for use of encrypted passwords
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = "$[Password]" #ISeC Credential password
$securePW = "$[SecurePW]"
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber

$ISEC_ID = "$[PatchDeployID]"
$IIDoutput = "$[Output format]"

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/deployments/'+$ISEC_ID+'/machines'
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

#Speak to ISeC REST API
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
  exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results 
#Let's built a new array, as this info is not in 1 table in the output
#We want to be compatible with the powershell api
# endpointname;bulletin;kb;overall state;status description;start date;end date

$PatchDetailedReport = @()
for ($countmachine = 0; $countmachine -le $result.count-1; $countmachine++) 
{
  #count machines
  for ($countpatch = 0; $countpatch -le $result.value[$countmachine].patchstates.count-1; $countpatch++) 
  {
    #count patches of machine

    $item = New-Object -TypeName PSObject
    $item | Add-Member -TypeName NoteProperty -Name 'endpointname' -Value $result.value[$countmachine].name
    $item | Add-Member -TypeName NoteProperty -Name 'bulletin' -Value $result.value[$countmachine].patchstates[$countpatch].bulletinID
    $item | Add-Member -TypeName NoteProperty -Name 'kb' -Value $result.value[$countmachine].patchstates[$countpatch].kb
    $item | Add-Member -TypeName NoteProperty -Name 'overallstate' -Value $result.value[$countmachine].patchstates[$countpatch].overallStateDescription
    $item | Add-Member -TypeName NoteProperty -Name 'statusdescription' -Value $result.value[$countmachine].patchstates[$countpatch].statusdescription
    $item | Add-Member -TypeName NoteProperty -Name 'startdate' -Value $result.value[$countmachine].patchstates[$countpatch].startedon
    $item | Add-Member -TypeName NoteProperty -Name 'enddate' -Value $result.value[$countmachine].patchstates[$countpatch].finishedon

    $PatchDetailedReport += $item
  }
}

#output to screen
if ($IIDoutput -eq '1') 
{
  $output = ''
  for ($count = 0; $count -le $PatchDetailedReport.count-1; $count++) 
  {
    if ($count -eq 0) 
    {
      $output = $PatchDetailedReport[$count].endpointname +';'+ $PatchDetailedReport[$count].bulletin +';'+ $PatchDetailedReport[$count].kb +';'+ $PatchDetailedReport[$count].overallstate +';'+ $PatchDetailedReport[$count].statusdescription +';'+ [datetime]$PatchDetailedReport[$count].startdate +';'+ [datetime]$PatchDetailedReport[$count].enddate
    }
    else 
    {
      $output = $output +'|'+ $PatchDetailedReport[$count].endpointname +';'+ $PatchDetailedReport[$count].bulletin +';'+ $PatchDetailedReport[$count].kb +';'+ $PatchDetailedReport[$count].overallstate +';'+ $PatchDetailedReport[$count].statusdescription +';'+ [datetime]$PatchDetailedReport[$count].startdate +';'+ [datetime]$PatchDetailedReport[$count].enddate
    }
  }
  $output
} else 
{
  $PatchDetailedReport | Format-Table -Wrap -AutoSize
}
