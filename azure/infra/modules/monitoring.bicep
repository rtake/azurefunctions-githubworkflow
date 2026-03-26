param resourceToken string
param monitorScopeId string

resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: 'ag-${resourceToken}'
  location: 'global'
  properties: {
    groupShortName: 'ag'
    enabled: true
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
