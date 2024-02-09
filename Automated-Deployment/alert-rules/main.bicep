@description('Specifies the Alert Rule Name.')
param  alertRuleName string = ''

@description('Specifies the Action Group Name.')
param actionGroupName string = ''

@description('Specifies the Action Group Location.')
param aglocation string = 'eastus2'

@description('Specifies the RG Location.')
param location string = resourceGroup().location

@description('Specifies Log Analytics Workspace Name.')
param lawName string = ''

@description('Specifies Custom Log Analytics Workspace Table Name. Do NOT Include _CL.')
param customTableName string = ''

@description('Specifies the Email Address for Alerts.')
param actionGroupEmail string = ''

resource LAW 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: lawName
}

resource supportTeamActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: aglocation
  properties: {
    enabled: true
    groupShortName: actionGroupName
    emailReceivers: [
      {
        name: actionGroupName
        emailAddress: actionGroupEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource  alertRule 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name:  alertRuleName
  location: location
  properties: {
    displayName:  alertRuleName
    severity: 3
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      LAW.id
    ]
    targetResourceTypes: [
      'microsoft.operationalinsights/workspaces'
    ]
    windowSize: 'PT5M'
    skipQueryValidation: false
    criteria: {
      allOf: [
        {
          query: '${customTableName}_CL\n| where event_type =~ "Microsoft.PolicyInsights.PolicyStateCreated" or event_type =~ "Microsoft.PolicyInsights.PolicyStateChanged"\n| where compliancestate =~ "NonCompliant"\n| extend TimeStamp = timestamp\n| extend Event_Type = event_type\n| extend Resource_Id = subject\n| extend Subscription_Id = subscriptionid\n| extend Compliance_State = compliancestate\n| extend Policy_Definition = policydefinitionid\n| extend Policy_Assignment = policyassignmentid\n| extend Compliance_Reason_Code = compliancereasoncode\n| project TimeStamp, Resource_Id, Subscription_Id, Policy_Assignment, Policy_Definition, Compliance_State, Compliance_Reason_Code\n'
          timeAggregation: 'Count'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        supportTeamActionGroup.id
      ]
      customProperties: {}
    }
  }
}

