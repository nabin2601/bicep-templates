// ============================================================
// Module: backup
// Creates:
//   - Recovery Services Vault
//   - Daily backup policy
//   - Backup protection for selected VMs
// ============================================================

@description('Azure region to deploy the resources to.')
param location string

@description('Name of the Recovery Services Vault.')
param vaultName string

@description('UTC backup run time in ISO 8601 format (example: 2026-04-05T23:00:00Z).')
param backupTime string

@description('Number of days to retain daily backups.')
@minValue(1)
param retentionDays int

@description('''
Array of VMs to protect.
Each object must contain:
- vmId   : Resource ID of the VM
- vmName : Name of the VM
- enable : true to enable backup
''')
param protectedVMs array

// ------------------------------------------------------------
// Variables
// ------------------------------------------------------------

var fabricName = 'Azure'
var backupPolicyName = 'DailyBackupPolicy'

// ------------------------------------------------------------
// Recovery Services Vault
// ------------------------------------------------------------

resource vault 'Microsoft.RecoveryServices/vaults@2025-08-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// ------------------------------------------------------------
// Backup Policy
// ------------------------------------------------------------

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-08-01' = {
  parent: vault
  name: backupPolicyName
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        backupTime
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          backupTime
        ]
        retentionDuration: {
          count: retentionDays
          durationType: 'Days'
        }
      }
    }
  }
}

// ------------------------------------------------------------
// Protected VM Backup Items
// ------------------------------------------------------------

resource backupProtectedItems 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-08-01' = [
  for item in protectedVMs: if (item.enable) {
    name: '${vault.name}/${fabricName}/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${item.vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${item.vmName}'
    location: location
    properties: {
      protectedItemType: 'Microsoft.Compute/virtualMachines'
      policyId: backupPolicy.id
      sourceResourceId: item.vmId
    }
  }
]

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

@description('Name of the Recovery Services Vault.')
output vaultOutputName string = vault.name

@description('Name of the backup policy.')
output backupPolicyOutputName string = backupPolicy.name


output vaultName string = vault.name
output backupPolicyName string = backupPolicy.name
