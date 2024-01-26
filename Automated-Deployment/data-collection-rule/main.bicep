@description('Specifies region of all resources.')
param location string = resourceGroup().location

@description('Specifies Data Collection Rule Name.')
param dcrName string = ''

@description('Specifies Data Collection Endpoint Name.')
param dceName string = ''

@description('Specifies Custom Log Analytics Workspace Table Name.')
param customTableName string = ''

@description('Specifies Log Analytics Workspace Name.')
param lawName string = ''

resource LAW 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: lawName
}

resource customLAWTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  // The name should end with '_CL'
  name: '${customTableName}_CL'
  parent: LAW
  properties: {
    schema: {
      // The name of the schema should be the same as the table resource name from above
      name: '${customTableName}_CL'
      columns: [
        {
          name: 'res_id'
          type: 'string'
        }
        {
          name: 'topic'
          type: 'string'
        }
        {
          name: 'subject'
          type: 'string'
        }
        {
          name: 'eventtime'
          type: 'datetime'
        }
        {
          name: 'event_type'
          type: 'string'
        }
        {
          name: 'compliancestate'
          type: 'string'
        }
        {
          name: 'compliancereasoncode'
          type: 'string'
        }
        {
          name: 'policydefinitionid'
          type: 'string'
        }
        {
          name: 'policyassignmentid'
          type: 'string'
        }
        {
          name: 'subscriptionid'
          type: 'string'
        }
        {
          name: 'timestamp'
          type: 'datetime'
        }
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
      ]
    }
  }
}

resource DCE 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: dceName
  location: location
  dependsOn: [
    customLAWTable
  ]
  properties: {
    configurationAccess: {}
    description: 'Data Collection Endpoint'
    logsIngestion: {}
    metricsIngestion: {}
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource DCR 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dataCollectionEndpointId: DCE.id
    description: 'Data Collection Rule'
    destinations: {
      logAnalytics: [
        {
          name: LAW.properties.customerId
          workspaceResourceId: LAW.id
        }
      ]
    }
    dataFlows: [
      {
        destinations: [
          LAW.properties.customerId
        ]
        // Streams below requires a "Custom-" prefix AND should match the name in dataFlows > streamDeclarations
        streams: ['Custom-${customTableName}_CL']
        // outputStream name should follow the DCR naming requirement of the "Custom-" prefix AND the LAW Name Req of a "_CL" Suffix
        outputStream: 'Custom-${customTableName}_CL'
        transformKql: 'source | extend TimeGenerated = todatetime(timestamp)'
      }
    ]
    streamDeclarations: {
      // Name should start with 'Custom-' AND Match dataFlows > Streams
      // Columns should match the Schema > Columns from the LAW Table Resource Above
      'Custom-${customTableName}_CL': {
        columns: [
          {
            name: 'res_id'
            type: 'string'
          }
          {
            name: 'topic'
            type: 'string'
          }
          {
            name: 'subject'
            type: 'string'
          }
          {
            name: 'eventtime'
            type: 'datetime'
          }
          {
            name: 'event_type'
            type: 'string'
          }
          {
            name: 'compliancestate'
            type: 'string'
          }
          {
            name: 'compliancereasoncode'
            type: 'string'
          }
          {
            name: 'policydefinitionid'
            type: 'string'
          }
          {
            name: 'policyassignmentid'
            type: 'string'
          }
          {
            name: 'subscriptionid'
            type: 'string'
          }
          {
            name: 'timestamp'
            type: 'datetime'
          }
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
        ]
      }
    }
  }
}

