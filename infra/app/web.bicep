param environmentName string
param location string = resourceGroup().location
param serviceName string = 'web'
param imageName string

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var abbrs = loadJsonContent('../abbreviations.json')

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${abbrs.insightsComponents}${resourceToken}'
}

resource api 'Microsoft.App/containerApps@2022-03-01' existing = {
  name: '${abbrs.appContainerApps}api-${resourceToken}'
}

module app '../core/host/container-app.bicep' = {
  name: 'web-containerapp-${serviceName}'
  params: {
    environmentName: environmentName
    location: location
    serviceName: serviceName
    targetPort: 80
    imageName: imageName
    env: [ {
      name: 'REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING'
      value: applicationInsights.properties.ConnectionString
    }
    {
      name: 'REACT_APP_API_BASE_URL'
      value: 'https://${api.properties.configuration.ingress.fqdn}'
    }
    {
      name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
      value: applicationInsights.properties.ConnectionString
    } ]
  }
}

output WEB_NAME string = app.outputs.NAME
output WEB_URI string = app.outputs.URI