@description('Specifies region of all resources.')
param location string = resourceGroup().location

@description('Function App Name.')
param functionAppName string = ''

@description('Function Trigger Name.')
param functionTriggerName string = ''

@description('App Service Plan Name.')
param appServicePlanName string = ''

@description('App Insights Name.')
param appInsightsName string = ''

@description('Storage Account Name.')
param storageAccountName string = ''

@description('Storage account SKU name.')
param storageSku string = ''

@description('App Service Plan SKU name.')
param appServicePlanSku string = ''

@description('Log Analytics Workspace name.')
param lawName string = ''

// These Value Need To Manually Be Entered >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
var logAnalyticsAPIVersion = '2021-06-01'
var functionScriptPath = '../function-app/run.ps1'
var functionReqPath = '../function-app/requirements.psd1'
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

resource LAW 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: lawName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: appServicePlanSku
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  tags: {}
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: plan.id
    reserved: false
    isXenon: false
    hyperV: false
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WORKSPACE_ID'
          value: '${reference(LAW.id, logAnalyticsAPIVersion).customerId}'
        }
        {
          name: 'WORKSPACE_KEY'
          value: '${listKeys(LAW.id, logAnalyticsAPIVersion).primarySharedKey}'
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: false
      }
      powerShellVersion: '7.2'
      netFrameworkVersion: 'v6.0'
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource functionCreate 'Microsoft.Web/sites/functions@2022-09-01' = {
  name: functionTriggerName
  parent: functionApp
  properties: {
    isDisabled: false
    language: 'PowerShell'
    config: {
      bindings: [
        {
          type: 'eventGridTrigger'
          //name: 'eventGridEvent' Maybe functionTriggerName?
          name: 'eventGridEvent'
          direction: 'in'
        }
      ]
    }
    files: {
      //'run.ps1': 'Write-Host \"Hello World!\"'
      'run.ps1' : loadTextContent('${functionScriptPath}')
      //'requirements.psd1' : loadTextContent('${functionReqPath}')
      '../requirements.psd1' : loadTextContent('${functionReqPath}')
    }
  }
}

output functionAppHostName string = functionApp.properties.defaultHostName
