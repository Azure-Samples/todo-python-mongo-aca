param accountName string
param location string = resourceGroup().location
param tags object = {}
param documentdbDatabaseName string = ''
param keyVaultResourceId string
param connectionStringKey string = 'AZURE-DOCUMENTDB-CONNECTION-STRING'
param collections array = [
  {
    name: 'TodoList'
    id: 'TodoList'
    shardKey: {
      keys: [
        'Hash'
      ]
    }
    indexes: [
      {
        key: {
          keys: [
            '_id'
          ]
        }
      }
    ]
  }
  {
    name: 'TodoItem'
    id: 'TodoItem'
    shardKey: {
      keys: [
        'Hash'
      ]
    }
    indexes: [
      {
        key: {
          keys: [
            '_id'
          ]
        }
      }
    ]
  }
]

var defaultDatabaseName = 'Todo'
var actualDatabaseName = !empty(documentdbDatabaseName) ? documentdbDatabaseName : defaultDatabaseName

module documentdb 'br/public:avm/res/document-db/database-account:0.6.0' = {
  name: 'documentdb-mongo'
  params: {
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    name: accountName
    location: location
    mongodbDatabases: [
      {
        name: actualDatabaseName
        tags: tags
        collections: collections
      }
    ]
    secretsExportConfiguration: {
      keyVaultResourceId: keyVaultResourceId
      primaryWriteConnectionStringSecretName: connectionStringKey
    }
  }
}

output connectionStringKey string = connectionStringKey
output databaseName string = actualDatabaseName
output endpoint string = documentdb.outputs.endpoint
