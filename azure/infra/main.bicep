param location string = resourceGroup().location

@description('Azure AI Foundry account region')
param aiFoundryLocation string = 'japaneast'

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
@secure()
param githubToken string = ''

var resourceToken = take(toLower(uniqueString(subscription().id, location)), 6)

module aiFoundry './modules/ai-foundry.bicep' = {
  name: 'aiFoundry'
  params: {
    resourceToken: resourceToken
    location: aiFoundryLocation
  }
}

module storageQueue './modules/storage-queue.bicep' = {
  name: 'storageQueue'
  params: {
    location: location
    resourceToken: resourceToken
  }
}

module functionApp './modules/function-app.bicep' = {
  name: 'functionApp'
  params: {
    location: location
    resourceToken: resourceToken
    runtime: runtime
    runtimeVersion: runtimeVersion
    githubOwner: githubOwner
    githubRepo: githubRepo
    githubToken: githubToken
    storageConnectionString: storageQueue.outputs.storageConnectionString
    queueName: storageQueue.outputs.queueName
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    resourceToken: resourceToken
    monitorScopeId: aiFoundry.outputs.devAccountId
  }
}

output devAiFoundryAccountName string = aiFoundry.outputs.devAccountName
output prodAiFoundryAccountName string = aiFoundry.outputs.prodAccountName
output functionAppName string = functionApp.outputs.functionName
