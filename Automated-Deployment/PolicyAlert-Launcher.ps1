#Requires -Modules @{ ModuleName="Az.Monitor"; ModuleVersion="5.0.0" }
#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.15.0" }
#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="6.14.0" }
#Requires -Modules @{ ModuleName="Az.OperationalInsights"; ModuleVersion="3.2.0" }
#Requires -Modules @{ ModuleName="Az.Functions"; ModuleVersion="4.0.7" }

param(
    [string]$AzureEnvironment = "AzureCloud",
    [string]$SubscriptionId = "",
    [string]$RGName = "rg-",
    [string]$Location = "eastus",
    [string]$functionAppName = "FNApp-",
    [string]$functionTriggerName = "PolicyAlertTrigger",
    [string]$appServicePlanName = "ASP-",
    [string]$appInsightsName = "AI-",
    [string]$storageAccountName = "",
    [string]$storageSku = "Standard_LRS",
    [string]$appServicePlanSku = "Y1",
    [string]$LAWName = "LAW-",
    [string]$eventGridSubName = "",
    [string]$topicName  = "",
    [string]$dcrName = "DCR-",
    [string]$dceName = "DCE-",
    [string]$customTableName = "PolicyAlert",
    [string]$functionBicep = ".\function-app\main.bicep",
    [string]$eventGridBicep = ".\event-grid\main.bicep",
    [string]$dcrBicep = ".\data-collection-rule\main.bicep",
    [string]$reminders = ".\reminders.txt",
    [string]$OutputFile = ".\PolicyAlert-Launcher-Log.log",
    [string]$ScriptVer = "v1.0.3"
)

Function Log {
    param(
        [string]$Out = "",
        [string]$MsgType = "Green"
    )
    $t = [System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss")
    set-variable -Name Now -Value $t -scope Script
    $Out = $Now +" ---- "+$Out
    $Out | add-content $Outputfile
    Write-Host $Out -ForegroundColor $MsgType
}
Function ErrorHandler($ErrMsg) {
    If ($ErrMsg){
        Log "Error Encountered" "Red"
        Log "Error Detail: $Error[0]" "Red"
        $Error.Clear()
    }
}

# Check Bicep Install
Try {
    $BicepInstalled = Invoke-expression -Command "bicep --version" -ErrorAction SilentlyContinue
    If ($BicepInstalled){
        Log "Bicep Installed...." "Green"
    } Else {
        Log "Bicep Missing" "Red"
        Log "Exiting Script" "Red"
        Read-Host "Press Any Key to Exit Script"
        Exit
   }
} Catch {
    ErrorHandler $Error
    Log "Error Caught Checking Bicep Install" "Red"
    Log "Exiting Script" "Red"
    Read-Host "Press Any Key to Exit Script"
    Exit
}

<# Begin Main Code Block
    Notes:
    Requirements:
        Powershell Az Module
        Bicep
#>

$Start = Get-Date
Log "Beginning PolicyAlert Launcher Script" "Green"
Log "Starting Process Time:  $Start"
Log "Script Version = $ScriptVer"
Log "OutputFile = $OutputFile"
Log "Parameter Values:  "
Log "Environment = $AzureEnvironment"
Log "SubscriptionID = $SubscriptionId"
Log "RGNAme = $RGName"
Log "Location = $Location"
Log "functionAppname = $functionAppName"
Log "functionTriggerName = $functionTriggerName"
Log "appServicePlanName = $appServicePlanName"
Log "appInsightsName = $appInsightsName"
Log "storageAccountName = $storageAccountName"
Log "storageSku = $storageSku"
Log "appServicePlanSku = $appServicePlanSku"
Log "LAWName = $LAWName"
Log "eventGridSubName = $eventGridSubName"
Log "topicName = $topicName"
Log "dcrName = $dcrName"
Log "dceName = $dceName"
Log "customTableName = $customTableName"
Log "functionBicep = $functionBicep"
Log "eventGridBicep = $eventGridBicep"
Log "dcrBicep = $dcrBicep"
Log "reminders = $reminders"
Log "OutputFile = $OutputFile"
Log "ScriptVer = $ScriptVer"
Log ""

Try {
    #Connect to Appropriate Azure Environment
    Log "Connecting to Azure"
    Connect-AzAccount -Environment $AzureEnvironment -SubscriptionId $SubscriptionId
    #Attach to the Correct Subscription
    Log "Setting Azure Subscription Context"
    Set-AzContext -SubscriptionId $SubscriptionId
} Catch {
    ErrorHandler $Error
    Log "Error Caught During Azure Connect and Subscription Context Setting" "Red"
    Log "Exiting Script" "Red"
    Exit
}

#Check if Resource Group exists and create it if it does not exist
Try {
    $Error.Clear()
    Log "Creating New or Binding to Existing RG"
    If (!(Get-AzResourceGroup -Name $RGName -ErrorAction SilentlyContinue)){
        Log "Resource Group Not Found.  Creating Now..."
        New-AzResourceGroup -Name $RGName -Location $Location
    } Else {
        Log "Resource Group Found.  Proceeding to Next Step."
        $RG = Get-AzResourceGroup -Name $RGName
    }
} Catch {
    ErrorHandler $Error
    Log "Error Caught During Creating/Binding to RG" "Red"
    Log "Exiting Script" "Red"
    Exit
}

#Check if LAW exists and create it if it does not exist
Try {
    $Error.Clear()
    Log "Creating New or Binding to Existing LAW"
    If (!(Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $LAWName -ErrorAction SilentlyContinue)){
        Log "LAW Not Found.  Creating Now..."
        New-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $LAWName -Location $Location
        # Begin Loop to Validate LAW Creation is Complete
        $Iteration = 0
        Do {$Iteration = $Iteration + 1 ; Log "LAW Creation Iteration: $Iteration" "Green" ; Start-Sleep -Seconds 5} Until (Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $LAWName -ErrorAction SilentlyContinue)
        $Iteration = $null
        Log "LAW Creation Validated"
    } Else {
        Log "LAW Found.  Proceeding to Next Step."
        $LAW = Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $LAWName
    }
} Catch {
    ErrorHandler $Error
    Log "Error Caught During Creating/Binding to RG" "Red"
    Log "Exiting Script" "Red"
    Exit
}

# Call Function App Bicep Template
# Setup Hashtable for Bicep Params
$FunctionDeployParams = @{
    functionAppName = $functionAppName
    functionTriggerName = $functionTriggerName
    appServicePlanName = $appServicePlanName
    appInsightsName = $appInsightsName
    storageAccountName = $storageAccountName
    keyVaultName = $keyVaultName
    keyVaultSku = $keyVaultSku
    storageSku = $storageSku
    appServicePlanSku = $appServicePlanSku
    lawName = $lawName
}

# Run Function App Bicep Template and Set Role Assignment
Try {
    Log "Entering Azure Function Section"
    Log "Calling Function Bicep Template"
    New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile $functionBicep -TemplateParameterObject $FunctionDeployParams
    Log "Entering Loop to Wait for Function App to Show Up"
    $Iteration = 0
    Do {$Iteration = $Iteration + 1 ; Log "Function App Iteration: $Iteration" "Green" ; Start-Sleep -Seconds 10} Until (Get-AzFunctionApp -Name $functionAppName -ResourceGroupName $RGName)
    $Iteration = $null
    Log "Function App Created" "Green"
} Catch {
    ErrorHandler $Error
    Log "Error Caught Launching Function App Bicep Deployment Or Add-Function-RoleAssignment.ps1" "Red"
    Log "Variables :: $RGNAME :: $functionBicep :: $FunctionDeployParams"
    Log "Exiting Script" "Red"
    Read-Host "Press Any Key to Exit Script"
    Exit
}

# Call Event Grid Bicep Template
# Setup Hashtable for Event Grid Bicep Params
$EventGridDeployParams = @{
    eventGridSubName = $eventGridSubName
    topicName = $topicName
    functionTriggerName = $functionTriggerName
    functionAppName = $functionAppName
}

# Run Event Grid Bicep Template
Try {
    Log "Calling Event Grid Bicep Template"
    New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile $eventGridBicep -TemplateParameterObject $EventGridDeployParams
} Catch {
    ErrorHandler $Error
    Log "Error Caught Launching Event Grid Bicep Deployment" "Red"
    Log "Variables :: $RGNAME :: $eventGridBicep :: $EventGridDeployParams"
    Log "Exiting Script" "Red"
    Read-Host "Press Any Key to Exit Script"
    Exit
}

# Call DCE/DCR Bicep Template
# Setup Hashtable for DCE/DCR Bicep Params
$dcrDeployParams = @{
    dcrName = $dcrName
    dceName = $dceName
    customTableName = $customTableName
    lawName = $lawName
}

# Run DCE/DCR Bicep Template
Try {
    Log "Calling DCE/DCR Bicep Template"
    New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile $dcrBicep -TemplateParameterObject $dcrDeployParams
    Log "Entering Loop to Wait for DCE/DCR to Show Up"
    $Iteration = 0
    Do {$Iteration = $Iteration + 1 ; Log "DCE/DCR Iteration: $Iteration" "Green" ; Start-Sleep -Seconds 10} Until (Get-AzDataCollectionRule -Name $dcrName -ResourceGroupName $RGName)
    $Iteration = $null
    Log "DCE/DCR Created" "Green"
    Log "Calling Add-DCR-RoleAssignment.ps1 Script"
    Log ".\data-collection-rule\Add-DCR-RoleAssignment.ps1 -dcrName $dcrName -functionAppName $functionAppName -RGName $RGName"
    .\data-collection-rule\Add-DCR-RoleAssignment.ps1 -dcrName $dcrName -functionAppName $functionAppName -RGName $RGName
    Log "DCE/DCR Role Assignment Created" 
} Catch {
    ErrorHandler $Error
    Log "Error Caught Launching DCE/DCR Bicep Deployment Or Running Add-DCR-RoleAssignment.ps1" "Red"
    Log "Variables :: $RGNAME :: $dcrBicep :: $dcrDeployParams"
    Log "Exiting Script" "Red"
    Read-Host "Press Any Key to Exit Script"
    Exit
}

Log "Generating Output Reminders"

Add-Content -Value "TableName: $customTableName" -Path $reminders
Add-Content -Value "DCR-ImmutableID: $((Get-AzDataCollectionRule -ResourceGroupName $RGName -Name $dcrName).ImmutableId)" -Path $reminders
Add-Content -Value "DCE-URI: $((Get-AzDataCollectionEndpoint -Name $dcename -ResourceGroupName $rgname).logingestionendpoint)" -Path $reminders


$Stop = Get-Date
Log "Output Log File Stored to: $Outputfile"
Log "Total Duration: $(($Stop-$Start).Minutes) Minutes"