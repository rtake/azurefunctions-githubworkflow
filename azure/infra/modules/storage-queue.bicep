param location string
@minLength(6)
param resourceToken string
param queueName string = 'queue-agentdeploy'

var storageName = 'st${resourceToken}'
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'

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

output storageConnectionString string = storageConnectionString
output queueName string = mainQueue.name
