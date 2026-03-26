param resourceToken string
param location string = 'japaneast'

var devAccountName = 'aif-${resourceToken}-dev'
var prodAccountName = 'aif-${resourceToken}-prod'

resource aiFoundryAccountDev 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: devAccountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiProperties: {}
    customSubDomainName: devAccountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    allowProjectManagement: true
    defaultProject: 'dev'
    associatedProjects: ['dev']
    publicNetworkAccess: 'Enabled'
    storedCompletionsDisabled: false
  }
}

resource aiFoundryAccountDevProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  parent: aiFoundryAccountDev
  name: 'dev'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource aiFoundryAccountProd 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: prodAccountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiProperties: {}
    customSubDomainName: prodAccountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    allowProjectManagement: true
    defaultProject: 'prod'
    associatedProjects: ['prod']
    publicNetworkAccess: 'Enabled'
    storedCompletionsDisabled: false
  }
}

resource aiFoundryAccountProdProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  parent: aiFoundryAccountProd
  name: 'prod'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

output devAccountName string = aiFoundryAccountDev.name
output devAccountId string = aiFoundryAccountDev.id
output devProjectName string = aiFoundryAccountDevProject.name
output prodAccountName string = aiFoundryAccountProd.name
output prodAccountId string = aiFoundryAccountProd.id
output prodProjectName string = aiFoundryAccountProdProject.name
