// ============================================================
//  Module: storage
//  Creates: Storage Account for VM boot diagnostics.
// ============================================================

@description('Azure region to deploy the resources to.')
param location string

@description('Name of the storage account')
param storageAccountName string


// Storage Account for boot diagnostics

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
    allowBlobPublicAccess: false
  }
}

//Output the storage account ID to be used in the virtual machine module

output storageAccountName string = storageAccount.name

output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
