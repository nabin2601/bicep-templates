// ============================================================================
// MODULE: Storage & Key Vault
// Resources: Storage Account, Key Vault, Key Vault Secret (SQL connection string)
// ============================================================================

@description('Location for storage account and key vault')
param location string = resourceGroup().location

@description('Name of the secret in Key Vault to store the SQL connection string')
param sqlConnectionStringSecretName string

@description('The name oof the applicatio')
param appName string

@description('The Web App managed identity principal ID for Key Vault access policy.')
param webAppPrincipalId string

@description('Environment tag value (e.g., "dev", "prod")')
param environment string

//Variables

var uniqueSuffix = uniqueString(resourceGroup().id)
var storageAccountName = 'storage${replace(appName, '-', '')}${uniqueSuffix}'
var keyVaultName = 'kv-${uniqueSuffix}'

// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: {
    environment: environment
    application: appName
  }
}

// Create Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01'={
    name: keyVaultName
    location: location

    properties: {
        enabledForDeployment: true
        enabledForTemplateDeployment: true
        enabledForDiskEncryption: true
        tenantId: subscription().tenantId
        sku: {
        family: 'A'
        name: 'standard'
        }
        accessPolicies: [
        {
            tenantId: subscription().tenantId
            objectId: webAppPrincipalId
            permissions: {
            secrets: [
                'get'
                'list'
            ]
            }
        }
        ]
    }
    tags: {
        environment: environment
        application: appName
    }
}

//key vault secret for SQL connection string
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' ={
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: sqlConnectionStringSecretName
  }
}

@description('The Storage Account name.')
output storageAccountName string = storageAccount.name

@description('The Storage Account resource ID.')
output storageAccountId string = storageAccount.id

@description('The Key Vault URI.')
output keyVaultUri string = keyVault.properties.vaultUri

@description('The Key Vault name.')
output keyVaultName string = keyVault.name

output sqlConnectionStringSecretId string = sqlConnectionStringSecret.id
