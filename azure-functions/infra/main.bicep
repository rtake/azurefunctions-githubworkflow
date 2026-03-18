param location string = resourceGroup().location

@description('Function runtime')
@allowed([
  'node'
  'python'
  'dotnet-isolated'
])
param runtime string = 'node'

@description('Runtime version')
param runtimeVersion string = '20'

@description('GitHub owner (non-secret, optional)')
param githubOwner string = ''

@description('GitHub repo (non-secret, optional)')
param githubRepo string = ''

@description('GitHub token with permissions to trigger workflow. Inject via CI, do NOT put in source.')
param githubToken string = ''

var resourceToken = take(toLower(uniqueString(subscription().id, location)), 6)

var storageName = 'st${resourceToken}'
var planName = 'plan-${resourceToken}'
var functionName = 'func-${resourceToken}'
var appInsightsName = 'appi-${resourceToken}'
var queueName = 'queue-agentdeploy'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource mainQueueService 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' = {
  parent: storage
  name: 'default'
  properties: {}
}

resource mainQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-09-01' = {
  parent: mainQueueService
  name: queueName
  properties: {}
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  sku: {
    tier: 'Consumption'
    name: 'Y1'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: '${runtime}|${runtimeVersion}'
      minTlsVersion: '1.2'
    }
  }

  resource appsettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage: storageConnectionString
      FUNCTIONS_WORKER_RUNTIME: runtime
      FUNCTIONS_EXTENSION_VERSION: '~4'

      // Application Insights
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString

      // GitHub info
      GITHUB_OWNER: githubOwner
      GITHUB_REPO: githubRepo
      GITHUB_TOKEN: githubToken

      QUEUE_CONNECTION_STRING: storageConnectionString
      QUEUE_NAME: queueName
    }
  }
}
