# Patch Templates - List
# for Ivanti Security Controls
# version 2019-08
#
# Changelog
# Aug 2019 - Changed limit of returned templates to 50 (was 10)
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = '^[ISeC Serviceaccount Username]' #ISeC Credential Username
$password = '^[ISeC Serviceaccount Password]' #ISeC Credential password
$servername = '^[ISeC Servername]' #ISeC console servername
$serverport = '^[ISeC REST API portnumber]' #ISeC REST API portnumber
$IIDoutput = "$[Output Format]" #IID Output or List output

#System variables
$Url = 'https://'+$servername+':'+$serverport+'/st/console/api/v1.0/patch/scanTemplates?count=50'
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
  Write-Host -Object 'Error (GetPatchTemplates)'
  Write-Host 'StatusCode:' $_.Exception.Response.StatusCode.value__ 
  Write-Host 'StatusDescription:' $_.Exception.Response.StatusDescription
  Write-Host 'Error Message:' $_.ErrorDetails.Message
  exit(1)
}

#REST API was OK. Go on
$result = ConvertFrom-Json -InputObject $result

#Results

if ($IIDoutput -eq 1) 
{
  for ($count = 0;$count -lt ($result.count); $count++) 
  {
    if ($count -eq ($result.count-1)) 
    {
      $output = $output + $result.value[$count].name +';' + $result.value[$count].id
    }
    else
    {
      $output = $output + $result.value[$count].name +';' + $result.value[$count].id + '|'
    }
  }
  $output
}
#List
if ($IIDoutput -eq 0) 
{
  $result.value |
  Sort-Object -Property name |
  Format-Table -AutoSize -Property name, id
}
