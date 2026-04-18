// ============================================================================
// MODULE: App Service
// Resources: App Service Plan, Web App (Production), Dev Deployment Slot,
//            Diagnostic Settings
// ============================================================================

@description('Location for App Service Plan and Web App')
param location string = resourceGroup().location

@description('The name of the application')
param appName string

@allowed([
  'P1v2'
  'P2v2'
  'P3v2'
  'S1'
  'S2'
  'S3'
])
@description('The SKU for the App Service Plan (e.g., "P1v2", "S1")')
param appServicePlanSku string

@description('Environment tag value (e.g., "dev", "prod")')
param environment string

@description('Number of instances for the App Service Plan')
@minValue(1)
@maxValue(10)
param AppserviceInstanceCount int

@description('Application insight connection string')
param applicationInsightsConnectionString string

@description('Log Analytics Workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string


var uniqueSuffix = uniqueString(resourceGroup().id)
var appServicePlanName = 'AppServicePlan-${appName}'
var webAppName = '${appName}-${uniqueSuffix}'

// Create App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01'= {
  name: appServicePlanName
  location: location
  kind:'linux'
  sku: {
    name: appServicePlanSku
    capacity: AppserviceInstanceCount
  }
  properties: {
    reserved: false // Set to true for Linux, false for Windows
  }
  tags: {
    Environment: environment
    app: appName
  }
}

// Create Web App
resource webApp 'Microsoft.Web/sites@2025-03-01' = {
  name: webAppName
  location: location
  kind: 'app, linux'
  identity: {
    type: 'SystemAssigned'
  }

   properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
      // Restrict access - only allow Azure Front Door traffic
      ipSecurityRestrictions: [
        {
          tag: 'ServiceTag'
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          priority: 100
          name: 'Allow traffic from Front Door'
        }
        {
          ipAddress: 'any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
      ]
    }
  }
  tags: {
    Environment: environment
    app: appName
  }
}

// create deployment slot for dev environment

resource devSlot 'Microsoft.Web/sites/slots@2025-03-01' = {
  name: 'dev'
  parent: webApp
  location: location
  kind: 'app, linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
      // Restrict access - only allow Azure Front Door traffic
      ipSecurityRestrictions: [
        {
          tag: 'ServiceTag'
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          priority: 100
          name: 'Allow traffic from Front Door'
        }
        {
          ipAddress: 'any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
      ]
    }
  }
  tags: {
    Environment: environment
    app: appName
  }
}

// Create Diagnostic Settings for Web App

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'send-to-log-analytics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
    ]
  }
}


// Outputs
@description('The Web App resource ID.')
output webAppId string = webApp.id

@description('The Web App name.')
output webAppName string = webApp.name

@description('The production slot hostname.')
output webAppHostName string = webApp.properties.defaultHostName

@description('The development slot hostname.')
output devSlotHostName string = devSlot.properties.defaultHostName

@description('The Web App system-assigned managed identity principal ID.')
output webAppPrincipalId string = webApp.identity.principalId
