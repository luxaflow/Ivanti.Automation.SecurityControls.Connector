# Operations - Wait (PatchDeploy)
# for Ivanti Security Controls
# version 2020-5
# 
# Check Operations from ISeC console
#
# patrick.kaak@ivanti.com
# @pkaak

#User variables
$username = "^[ISeC Serviceaccount Username]" #ISeC Credential Username
$password = "^[ISeC Serviceaccount Password]" #ISeC Credential password
$servername = "^[ISeC Servername]" #ISeC console servername
$serverport = "^[ISeC REST API portnumber]" #ISeC REST API portnumber

$ISEC_ID = "$[PatchDeployID]"
$CheckSeconds ="$[Check every x seconds]"
$Logtime = "$[Log datetime and status]"

#System variables
$Url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/operations/"+$ISEC_ID
$EncryptPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $encryptpassword
$Running = ""
$Operations = "" #What is the endresult of operations

# We are going to WAIT till the Operation is finished.
# So do a loop till result.status <> Running

do { 
    #Connect to ISeC REST API
    try {
        $result = Invoke-RestMethod -Method Get -Credential $cred -URI $Url -ContentType "application/json" | ConvertTo-Json -Depth 99
    } catch {
        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        Write-Host "Error (OperationsWait)"
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        Write-Host "Error Message:" $_.ErrorDetails.Message
        exit (1)
    }

    #REST API was OK. Go on
    $result = ConvertFrom-Json $result
    if ($logtime -eq "True") { 
        $datetime = get-date -format "MM/dd/yyyy HH:mm:ss"
        write-host $datetime "Operations" $result.status
        }
    $running = $result.status

    if ($running -eq "Running") { 
        start-sleep -s $CheckSeconds # Do not burden the REST API too much if we are still busy scanning
        }
} until ($running -ne "Running")

$Operations = $Running

#It looks like we are finished
#Do a double check on this

$Url = "https://"+$servername+":"+$serverport+"/st/console/api/v1.0/patch/deployments/"+$ISEC_ID
$Running = ""

# We are going to WAIT till the Deployment is finished.
# So do a loop till result.isCompleted = True

do { 
    #Connect to ISeC REST API
    try {
        $result = Invoke-RestMethod -Method Get -Credential $cred -URI $Url -ContentType "application/json" | ConvertTo-Json -Depth 99
    } catch {
        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        Write-Host "Error (DeploymentsCheck)"
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        Write-Host "Error Message:" $_.ErrorDetails.Message
        exit (3)
    }

    #REST API was OK. Go on
    $result = ConvertFrom-Json $result
    if ($logtime -eq "True") { 
        $datetime = get-date -format "MM/dd/yyyy HH:mm:ss"
        write-host $datetime "DeploymentCheck, we are finished:" $result.isComplete
        }
    $running = $result.isComplete

    if ($running -ne "True") { 
        start-sleep -s $CheckSeconds # Do not burden the REST API too much if we are still busy scanning
        }
} until ($running -eq "True")


#We are finished
if ($Operations -eq "Succeeded")  {
    write-host $Operations
    exit(0)
} else {
    write-host $Operations
    exit(2)
}
