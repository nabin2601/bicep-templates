// ============================================================================
// MODULE: Database
// Resources: Azure SQL Server, SQL Firewall Rule, SQL Database,
//            Azure Cache for Redis
// ============================================================================

@description('The name of the application.')
param appName string

@description('The location where resources will be deployed.')
param location string

@description('Environment tag for resources.')
param environment string

@description('Azure SQL Database SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sqlDatabaseSku string

@description('Admin username for SQL Database.')
param sqlAdminUsername string

@description('Admin password for SQL Database. Must be complex.')
@secure()
param sqlAdminPassword string

// ============================================================================
// VARIABLES
// ============================================================================

var uniqueSuffix = uniqueString(resourceGroup().id)
var sqlServerName = 'sqlserver-${appName}-${uniqueSuffix}'
var sqlDatabaseName = '${appName}db'
var redisCacheName = 'cache-${appName}-${uniqueSuffix}'

// ============================================================================
// RESOURCE: Azure SQL Server
// ============================================================================

resource sqlServer 'Microsoft.Sql/servers@2021-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// RESOURCE: SQL Server Firewall - Allow Azure Services
// ============================================================================

resource sqlFirewall 'Microsoft.Sql/servers/firewallRules@2021-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// RESOURCE: Azure SQL Database
// ============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: sqlDatabaseSku
    tier: sqlDatabaseSku
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// RESOURCE: Azure Cache for Redis
// ============================================================================

resource redisCache 'Microsoft.Cache/redis@2021-06-01' = {
  name: redisCacheName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The SQL Server fully qualified domain name.')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('The SQL Server name.')
output sqlServerName string = sqlServer.name

@description('The SQL Database name.')
output sqlDatabaseName string = sqlDatabase.name

@description('The Redis Cache hostname.')
output redisCacheHostName string = redisCache.properties.hostName

output sqlConnectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
