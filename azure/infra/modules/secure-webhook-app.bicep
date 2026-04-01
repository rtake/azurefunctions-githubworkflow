extension microsoftGraphV1

@description('Stable token used to make Entra object names unique.')
param resourceToken string

@description('Tenant ID where the app registration is created.')
param tenantId string

var applicationDisplayName = 'ag-webhook-${resourceToken}'
var identifierUri = 'api://ag-webhook-${resourceToken}'
var actionGroupRoleName = 'ActionGroupsSecureWebhook'
var actionGroupRoleId = guid(resourceToken, actionGroupRoleName)
var azureMonitorActionGroupsAppId = '461e8683-5575-4561-ac7f-899cc907d62a'

resource webhookApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'ag-webhook-${resourceToken}'
  displayName: applicationDisplayName
  description: 'Protected API used by Azure Monitor Action Group secure webhook'
  signInAudience: 'AzureADMyOrg'
  identifierUris: [
    identifierUri
  ]
  api: {
    requestedAccessTokenVersion: 2
  }
  appRoles: [
    {
      id: actionGroupRoleId
      allowedMemberTypes: [
        'Application'
      ]
      description: 'Allow Azure Monitor Action Group to invoke the protected webhook'
      displayName: actionGroupRoleName
      isEnabled: true
      value: actionGroupRoleName
    }
  ]
  owners: {
    relationships: [
      '${azureMonitorActionGroupsSp.id}'
    ]
  }
}

resource webhookServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: webhookApp.appId
}

resource azureMonitorActionGroupsSp 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: azureMonitorActionGroupsAppId
}

resource azureMonitorWebhookAppRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  appRoleId: actionGroupRoleId
  principalId: azureMonitorActionGroupsSp.id
  resourceDisplayName: webhookApp.displayName
  resourceId: webhookServicePrincipal.id
}

output appObjectId string = webhookApp.id
output appId string = webhookApp.appId
output identifierUri string = identifierUri
output tenantId string = tenantId
output appRoleId string = actionGroupRoleId
