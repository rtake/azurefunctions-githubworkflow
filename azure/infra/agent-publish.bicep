param accountName string
param projectName string
param agentName string
param agentId string
param agentVersion string
param deploymentId string

resource account 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' existing = {
  parent: account
  name: projectName
}

resource application 'Microsoft.CognitiveServices/accounts/projects/applications@2025-10-01-preview' = {
  parent: project
  name: agentName
  properties: {
    displayName: agentName
    agents: [
      {
        agentId: agentId
        agentName: agentName
      }
    ]
    authorizationPolicy: {
      authorizationScheme: 'Default'
    }
    trafficRoutingPolicy: {
      protocol: 'FixedRatio'
      rules: [
        {
          ruleId: 'default'
          description: 'Default rule routing all traffic to the first deployment'
          deploymentId: deploymentId
          trafficPercentage: 100
        }
      ]
    }
  }
}

resource agentDeployment 'Microsoft.CognitiveServices/accounts/projects/applications/agentDeployments@2025-10-01-preview' = {
  parent: application
  name: '${agentName}-${agentVersion}'
  properties: {
    displayName: agentName
    deploymentId: deploymentId
    state: 'Running'
    protocols: [
      {
        protocol: 'Responses'
        version: '1.0'
      }
    ]
    agents: [
      {
        agentName: agentName
        agentVersion: agentVersion
      }
    ]
    deploymentType: 'Managed'
  }
}
