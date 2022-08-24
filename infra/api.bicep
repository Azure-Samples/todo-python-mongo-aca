@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

param imageName string

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }
var abbrs = loadJsonContent('abbreviations.json')

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: '${abbrs.appManagedEnvironments}${resourceToken}'
}

// 2022-02-01-preview needed for anonymousPullEnabled
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: '${abbrs.containerRegistryRegistries}${resourceToken}'
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${abbrs.insightsComponents}${resourceToken}'
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: '${abbrs.keyVaultVaults}${resourceToken}'
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' existing = {
  name: '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
}

resource api 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${abbrs.appContainerApps}api-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 3100
        transport: 'auto'
      }
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          image: imageName
          name: 'main'
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
          ]
        }
      ]
    }
  }
}


// create connection between api and keyvault
// todo: register servicelinker RP https://github.com/Azure/bicep/issues/3267
resource linkerToKeyVault 'Microsoft.ServiceLinker/linkers@2022-05-01' = {
  name: '${abbrs.serviceLinkerKVlinker}${resourceToken}'
  scope: api
  properties: {
    targetService: {
      id: keyVault.id
      resourceProperties: {
        connectAsKubernetesCsiDriver: false
        type: 'KeyVault'
      }
      type: 'AzureResource'
    }
    clientType: 'none'
    scope: 'main'
    authInfo: {
      authType: 'systemAssignedIdentity'
    }
  }
}

// create connection between api and cosmosdb
resource linkerToCosmosdb 'Microsoft.ServiceLinker/linkers@2022-05-01' = {
  name: '${abbrs.serviceLinkerCosmoslinker}${resourceToken}'
  scope: api
  properties: {
    targetService: {
      type: 'AzureResource'
      id: '${cosmos.id}/mongodbDatabases/Todo'
    }    
    clientType: 'none'
    scope: 'main'
    authInfo: {
      authType: 'secret'
      secretInfo: {
        secretType: 'rawValue'
      }
    }
    secretStore: {
      keyVaultId: keyVault.id
    }
  }
  dependsOn: [
    linkerToKeyVault
  ]
}

// resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2021-10-01' = {
//   name: '${keyVault.name}/add'
//   properties: {
//     accessPolicies: [
//       {
//         objectId: api.identity.principalId
//         permissions: {
//           secrets: [
//             'get'
//             'list'
//           ]
//         }
//         tenantId: subscription().tenantId
//       }
//     ]
//   }
// }

output API_URI string = 'https://${api.properties.configuration.ingress.fqdn}'
