// ============================================================================
// MAIN: Azure Infrastructure Orchestrator
// Deploys: App Service + Front Door + WAF + Deployment Slots + Database
//          + Redis Cache + Storage + Key Vault + Monitoring
//
// Usage:
//   az deployment group create \
//     --resource-group <your-rg> \
//     --template-file main.bicep \
//     --parameters @parameters.production.json
// ============================================================================

@minLength(1)
@maxLength(30)
@description('The name of the application. Must be globally unique.')
param appName string = 'myapp'

@description('The location where resources will be deployed.')
param location string = resourceGroup().location

@description('The SKU for App Service Plan. Use S1 or higher for deployment slots.')
@allowed([
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string = 'S1'

@description('Number of instances for App Service Plan.')
@minValue(1)
@maxValue(10)
param appServiceInstanceCount int = 1

@description('Azure SQL Database SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sqlDatabaseSku string = 'Standard'

@description('Admin username for SQL Database.')
param sqlAdminUsername string = 'dbadmin'

@description('Admin password for SQL Database. Must be complex.')
@secure()
param sqlAdminPassword string

@description('Front Door SKU - Standard or Premium (Premium required for full WAF).')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSku string = 'Premium_AzureFrontDoor'

@description('Enable WAF on Front Door.')
param enableWaf bool = true

@description('Environment tag for resources.')
param environment string = 'production'

// ============================================================================
// MODULE: Monitoring (Log Analytics + Application Insights)
// ============================================================================

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    appName: appName
    location: location
    environment: environment
  }
}

// ============================================================================
// MODULE: App Service (Plan + Web App + Dev Slot + Diagnostics)
// ============================================================================

module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  params: {
    appName: appName
    location: location
    environment: environment
    appServicePlanSku: appServicePlanSku
    AppserviceInstanceCount: appServiceInstanceCount
    applicationInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// ============================================================================
// MODULE: Database (SQL Server + SQL Database + Redis Cache)
// ============================================================================

module database 'modules/database.bicep' = {
  name: 'database-deployment'
  params: {
    appName: appName
    location: location
    environment: environment
    sqlDatabaseSku: sqlDatabaseSku
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
  }
}

// ============================================================================
// MODULE: Storage & Key Vault
// ============================================================================

module storageKeyVault 'modules/storage-keyvault.bicep' = {
  name: 'storage-keyvault-deployment'
  params: {
    appName: appName
    location: location
    environment: environment
    webAppPrincipalId: appService.outputs.webAppPrincipalId
    sqlConnectionStringSecretName: 'sqlConnectionString'
  }
}

// ============================================================================
// MODULE: Front Door & WAF
// ============================================================================

module frontDoor 'modules/frontdoor-waf.bicep' = {
  name: 'frontdoor-waf-deployment'
  params: {
    appName: appName
    environment: environment
    frontDoorSku: frontDoorSku
    enableWaf: enableWaf
    appServiceHostName: appService.outputs.webAppHostName
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The App Service production slot hostname.')
output appServiceHostName string = appService.outputs.webAppHostName

@description('The development deployment slot hostname.')
output devSlotHostName string = appService.outputs.devSlotHostName

@description('The Azure Front Door endpoint hostname.')
output frontDoorHostName string = frontDoor.outputs.frontDoorHostName

@description('The SQL Server fully qualified domain name.')
output sqlServerFqdn string = database.outputs.sqlServerFqdn

@description('The SQL Database name.')
output sqlDatabaseName string = database.outputs.sqlDatabaseName

@description('The Redis Cache hostname.')
output redisCacheHostName string = database.outputs.redisCacheHostName

@description('The Storage Account name.')
output storageAccountName string = storageKeyVault.outputs.storageAccountName

@description('The Key Vault URI.')
output keyVaultUri string = storageKeyVault.outputs.keyVaultUri

@description('The Log Analytics Workspace ID.')
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId

@description('The Application Insights instrumentation key.')
output appInsightsInstrumentationKey string = monitoring.outputs.appInsightsInstrumentationKey

@description('The Resource Group ID.')
output resourceGroupId string = resourceGroup().id
