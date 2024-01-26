param($EventGridEvent, $TriggerMetaData)

############### BEGIN USER SPECIFIED VARIABLES ###############
############### Please fill in values for all Variables in this section. ###############

# Specify the name of the LAW Table that you will be sending data to
$Table = "Custom-Table-Name"

# Specify the Immutable ID of the DCR
$DcrImmutableId = "dcr-Immutable-Id"

# Specify the URI of the DCE
$DceURI = "dce-URI"

############### END USER SPECIFIED VARIABLES ###############
<#
    "Sample Logging Example" | Out-String | Write-Host
#>


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
$bearerToken = (Get-AzAccessToken -ResourceUrl "https://monitor.azure.com/").Token

# Sending the data to Log Analytics via the DCR!
$body = $json
$headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
$uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$Table"+"_CL?api-version=2021-11-01-preview";
$uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers;

$uploadResponse | Out-String | Write-Host