@description('Stable token used to derive names.')
param resourceToken string

@description('Scope for the activity log alert.')
param monitorScopeId string

@description('Tenant ID for secure webhook auth.')
param tenantId string

@description('Protected webhook endpoint URL.')
param serviceUri string

@description('Microsoft Entra application object ID for the protected webhook.')
param webhookAppObjectId string

resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: 'ag-${resourceToken}'
  location: 'global'
  properties: {
    groupShortName: 'ag'
    enabled: true
    webhookReceivers: [
      {
        name: 'azureFunctionsSecureWebhook'
        serviceUri: serviceUri
        tenantId: tenantId
        objectId: webhookAppObjectId
        useAadAuth: true
        useCommonAlertSchema: true
      }
    ]
  }
}

resource alertRule 'microsoft.insights/activityLogAlerts@2017-04-01' = {
  name: 'alert-${resourceToken}'
  location: 'global'
  properties: {
    description: 'Alert for function failures'
    enabled: true
    scopes: [
      monitorScopeId
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}
