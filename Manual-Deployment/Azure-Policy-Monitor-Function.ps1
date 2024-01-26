param($EventGridEvent, $TriggerMetaData)

############### BEGIN USER SPECIFIED VARIABLES ###############
############### Please fill in values for all Variables in this section. ###############

# Specify the name of the LAW Table that you will be sending data to
$Table = "PolicyAlert"

# Specify the Immutable ID of the DCR
$DcrImmutableId = "dcr-MyImmutableID"

# Specify the URI of the DCE
$DceURI = "https://dce-name.region.ingest.monitor.azure.com"

# Specify the KeyVault Name and the Secret Name
$KeyVaultName = "KV-PolicyAlert"
$SecretName = "PolicyAlert-Secret"

# Login to Azure as the Azure FUnction Managed Identity and Grab the Secret from the Keyvault
Connect-AzAccount -Identity | Out-String | Write-Host
$appSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText

# Specify the AAD Tenant ID and Registered App ID in AAD for Accessing the DCE
$tenantId = "MY-AAD-Tenant-ID"; #the tenant ID in which the Data Collection Endpoint resides
$appId = "MY-Registered-AppID"; #the app ID created and granted permissions

############### END USER SPECIFIED VARIABLES ###############


# JSON Value
$json = @"
[{  "res_id": "$($EventGridEvent.id)",
    "topic": "$($EventGridEvent.topic)",
    "subject": "$($EventGridEvent.subject)",
    "eventtime": "$($EventGridEvent.eventTime)",
    "event_type": "$($EventGridEvent.eventType)",
    "compliancestate": "$($EventGridEvent.data.complianceState)",
    "compliancereasoncode": "$($EventGridEvent.data.complianceReasonCode)",
    "policydefinitionid": "$($EventGridEvent.data.policyDefinitionId)",
    "policyassignmentid": "$($EventGridEvent.data.policyAssignmentId)",
    "subscriptionid": "$($EventGridEvent.data.subscriptionId)",
    "timestamp": "$($EventGridEvent.data.timestamp)"
}]
"@

## Obtain a bearer token used to authenticate against the data collection endpoint
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
$headers = @{"Content-Type" = "application/x-www-form-urlencoded" };
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$bearerToken = (Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers).access_token


# Sending the data to Log Analytics via the DCR!
$body = $json
$headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
$uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$Table"+"_CL?api-version=2021-11-01-preview";
$uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers;

$uploadResponse | Out-String | Write-Host