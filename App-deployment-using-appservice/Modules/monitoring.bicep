// ============================================================================
// MODULE: Monitoring
// Resources: Log Analytics Workspace, Application Insights
// ============================================================================

@description('The name of the application.')
param appName string

@description('The location where resources will be deployed.')
param location string

@description('Environment tag for resources.')
param environment string

// ============================================================================
// VARIABLES
// ============================================================================

var appInsightsName = 'appinsights-${appName}'
var logAnalyticsName = 'logs-${appName}'

// ============================================================================
// RESOURCE: Log Analytics Workspace
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// RESOURCE: Application Insights
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The Log Analytics Workspace resource ID.')
output logAnalyticsId string = logAnalytics.id

@description('The Log Analytics Workspace ID (GUID).')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('The Application Insights connection string.')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('The Application Insights instrumentation key.')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
