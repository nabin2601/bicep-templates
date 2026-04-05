// ============================================================
//  main.bicep  —  entry point
//
//  Module layout:
//    modules/
//      networking.bicep     → VNet, subnets, Bastion, public IP
//      storage.bicep        → Storage account (boot diagnostics)
//      virtualMachine.bicep → NIC + VM  (called once per vmConfig)
//      backup.bicep         → Recovery Vault, policy, protected items
// ============================================================

@description('Azure region to deploy the resources to.')
param location string = resourceGroup().location


// Virtual Network parameters

@description('Name of the virtual network')
param vnetName string = 'myVnet'

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '172.16.0.0/16'

@description('Name of the subnet for the virtual machines')
param vmSubnetAddressPrefix string = '172.16.53.0/24'

@description('Name of the subnet for the Bastion host')
param bastionHostName string = 'myBastionHost'

@description('Name of the Bastion public IP')
param bastionPublicIpName string = 'myBastionPublicIP'

@description('Bastion address prefix')
param bastionSubnetAddressPrefix string = '172.16.0.0/27'

// Storage parameters

@description('Name of the storage account for boot diagnostics, this must be globally unique')
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'

// Virtual Machine parameters

@description('Admin username for the virtual machines')
param adminUsername string = 'azureuser'

@description('Admin password for the virtual machines')
@secure()
param adminPassword string

@allowed([
  'Standard_B1s'
  'Standard_B2s'
  'Standard_D2s_v3'
  'Standard_D4s_v3'
])
@description('Size of the virtual machine')
param defaultVmSize string = 'Standard_B1s'

@description('''
Array of VM definitions. Supported fields per entry:
  - vmName       (required) 3-15 chars; used for VM, NIC, and OS disk names
  - vmSize       (optional) overrides defaultVmSize for this VM only
  - enableBackup (optional) set to false to skip backup registration; default true

Example:
[
  { vmName: 'web01' }
  { vmName: 'app01', vmSize: 'Standard_B4ms' }
  { vmName: 'db01',  vmSize: 'Standard_B4ms', enableBackup: false }
]
''')
param vmConfigs array = [
  { vmName: 'vm-001' }
  { vmName: 'vm-002', vmSize: 'Standard_B2s' }
]

// Backup parameters

@description('Name of the Recovery Services vault for backup')
param vaultName string = 'myRecoveryServicesVault'

@description('Time to schedule the backup job (24hr format, UTC)')
param backupTime string = '02:00'

@description('Number of days to retain the backup')
param retentionDays int = 1


// Module : Networking

module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    bastionHostName: bastionHostName
    bastionPublicIpName: bastionPublicIpName
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    vmSubnetAddressPrefix: vmSubnetAddressPrefix
  }
}

// Module : Storage

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// Module : Virtual Machine (called once per vmConfig entry)

module virtualMachine 'modules/virtualmachine.bicep' = [
  for vm in vmConfigs: {
  name: 'vm-${vm.vmName}'
  params: {
    location: location
    vmName: vm.vmName
    vmSize: vm.?vmSize ?? defaultVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: networking.outputs.vmSubnetId
  }
}]

// Module : Backup

module backup 'modules/backup.bicep' = {
  name: 'backup'
  params: {
    location: location
    vaultName: vaultName
    backupTime: backupTime
    retentionDays: retentionDays
    protectedVMs: [
      for (vm, i) in vmConfigs: {
        vmId: virtualMachine[i].outputs.vmId
        vmName: vm.vmName
        enable: vm.?enableBackup ?? true
      }
    ]
  }
}

// Outputs
output vaultName        string = backup.outputs.vaultName
output backupPolicyName string = backup.outputs.backupPolicyName
output storageAccount   string = storage.outputs.storageAccountName

output deployedVMs array = [
  for (vm, i) in vmConfigs: {
    vmName:        vm.vmName
    nicName:       '${vm.vmName}-nic'
    backupEnabled: vm.?enableBackup ?? true
  }
]
