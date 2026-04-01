param location string
param resourceToken string
param runtime string
param runtimeVersion string
param githubOwner string
param githubRepo string
@secure()
param githubToken string
param storageConnectionString string
param queueName string
param aadClientId string
param tenantId string

var planName = 'plan-${resourceToken}'
var functionName = 'func-${resourceToken}'
var appInsightsName = 'appi-${resourceToken}'

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
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
      GITHUB_OWNER: githubOwner
      GITHUB_REPO: githubRepo
      GITHUB_TOKEN: githubToken
      QUEUE_CONNECTION_STRING: storageConnectionString
      QUEUE_NAME: queueName
    }
  }
}

resource auth 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: aadClientId
          openIdIssuer: 'https://sts.windows.net/${tenantId}/'
        }
        validation: {
          allowedAudiences: [
            'api://${aadClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

output functionName string = functionApp.name
output functionPrincipalId string = functionApp.identity.principalId
