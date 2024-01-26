param (
    [Parameter(Mandatory)] [string]$dcrName = "",
    [Parameter(Mandatory)] [string]$functionAppName = "",
    [Parameter(Mandatory)] [string]$RGName = ""
)

# Begin Loop to Validate DCR Exists
$Iteration = 0
Do {$Iteration = $Iteration + 1 ; Log "DCR Exists Iteration: $Iteration" "Green" ; Start-Sleep -Seconds 5} Until (Get-AzDataCollectionRule -ResourceGroupName $RGName -Name $dcrName -ErrorAction SilentlyContinue)
$Iteration = $null

$User = (Get-AzADServicePrincipal -DisplayName $functionAppName).id
$Scope = (Get-AzDataCollectionRule -ResourceGroupName $RGName -Name $dcrName).Id

New-AzRoleAssignment -ObjectId $User -RoleDefinitionName "Monitoring Metrics Publisher" -Scope $Scope