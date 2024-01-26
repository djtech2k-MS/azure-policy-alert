@description('Event Grid Subscription Name (Not Azure Subscription).')
param eventGridSubName string = ''

@description('Event Grid System Topic Name.')
param topicName string = ''

@description('Function Trigger Name.')
param functionTriggerName string = ''

@description('Function App Name.')
param functionAppName string = ''

@description('Function App Name.')
param egSubscriptionSource string = subscription().id

resource functionTrigger 'Microsoft.Web/sites/functions@2023-01-01' existing = {
  name: '${functionAppName}/${functionTriggerName}'
}

resource evtTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: topicName
  location: 'global'
  properties: {
    source: egSubscriptionSource
    topicType: 'Microsoft.PolicyInsights.PolicyStates'
  }
}

resource evtGridSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: evtTopic
  name: eventGridSubName
  properties: {
    eventDeliverySchema: 'EventGridSchema'
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: functionTrigger.id
        maxEventsPerBatch: 1
				preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      subjectBeginsWith: ''
      subjectEndsWith: ''
      includedEventTypes: [
        'Microsoft.PolicyInsights.PolicyStateChanged'
        'Microsoft.PolicyInsights.PolicyStateCreated'
        //'Microsoft.PolicyInsights.PolicyStateDeleted'
      ]
      enableAdvancedFilteringOnArrays: true
    }
  }
}

output FNAppId string = functionTrigger.id
