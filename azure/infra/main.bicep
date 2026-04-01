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

@description('AAD Client ID for Azure Functions authentication. Inject via CI, do NOT put in source.')
param aadClientId string = '00000000-0000-0000-0000-000000000000' // dummy

@description('GitHub owner (non-secret, optional)')
param githubOwner string = ''

@description('GitHub repo (non-secret, optional)')
param githubRepo string = ''

@description('GitHub token with permissions to trigger workflow. Inject via CI, do NOT put in source.')
@secure()
param githubToken string = ''

var resourceToken = take(toLower(uniqueString(resourceGroup().id, location)), 6)
var tenantId = tenant().tenantId

var devAiFoundryAccountName = 'aif-${resourceToken}-dev'
var prodAiFoundryAccountName = 'aif-${resourceToken}-prod'

// Role definition
var cognitiveServicesUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Service User
)
var azureAiUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d' // Azure AI User
)
var resourceGroupContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c' // Resource Group Contributor
)

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
    tenantId: tenantId
    aadClientId: aadClientId
  }
}

module secureWebhookApp './modules/secure-webhook-app.bicep' = {
  name: 'secureWebhookApp'
  params: {
    resourceToken: resourceToken
    tenantId: tenantId
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    resourceToken: resourceToken
    monitorScopeId: aiFoundry.outputs.devAccountId
    tenantId: tenantId
    serviceUri: 'https://${functionApp.outputs.functionName}.azurewebsites.net'
    webhookAppObjectId: secureWebhookApp.outputs.appObjectId
    webhookIdentifierUri: secureWebhookApp.outputs.identifierUri
  }
}

module githubworkflowServicePrincipal './modules/githubactions-serviceprincipal.bicep' = {
  name: 'githubworkflowServicePrincipal'
  params: {
    resourceToken: resourceToken
    githubOwner: githubOwner
    githubRepo: githubRepo
  }
}

resource devAiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: devAiFoundryAccountName
}
resource prodAiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: prodAiFoundryAccountName
}

// Azure FunctionsにCognitive Service Userロールを割り当てる
resource functionAppCognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, devAiFoundryAccountName, 'function-app-cognitive-services-user')
  scope: devAiFoundryAccount
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleDefinitionId
    principalId: functionApp.outputs.functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// GitHub Actions用のサービスプリンシパルにCognitive Service Userロールを割り当てる
resource githubworkflowServicePrincipalRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(prodAiFoundryAccount.id, githubOwner, githubRepo, 'service-principal-cognitive-services-user')
  scope: prodAiFoundryAccount
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleDefinitionId
    principalId: githubworkflowServicePrincipal.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// GitHub Actions用のサービスプリンシパルにAzure AI ユーザーロールを割り当てる
resource githubworkflowServicePrincipalAiUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(prodAiFoundryAccount.id, githubOwner, githubRepo, 'service-principal-azure-ai-user')
  scope: prodAiFoundryAccount
  properties: {
    roleDefinitionId: azureAiUserRoleDefinitionId
    principalId: githubworkflowServicePrincipal.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// GitHub Actions用のサービスプリンシパルにリソースグループの共同作成者ロールを割り当てる
resource githubworkflowServicePrincipalContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, githubOwner, githubRepo, 'service-principal-resource-group-contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceGroupContributorRoleDefinitionId
    principalId: githubworkflowServicePrincipal.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

output devAiFoundryAccountName string = aiFoundry.outputs.devAccountName
output prodAiFoundryAccountName string = aiFoundry.outputs.prodAccountName
output functionAppName string = functionApp.outputs.functionName
