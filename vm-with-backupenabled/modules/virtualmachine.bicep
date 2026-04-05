// ============================================================
//  Module: virtualMachine
//  Creates: one NIC + one Windows VM.
//  Called in a loop from main.bicep — once per vmConfig entry.
// ============================================================

@description('Azure region to deploy the resources to.')
param location string

@description('Name of the virtual machine')
param vmName string

@allowed([
  'Standard_B1s'
  'Standard_B2s'
  'Standard_D2s_v3'
  'Standard_D4s_v3'
])

@description('Size of the virtual machine')
param vmSize string = 'Standard_B1s'

@description('Name of the admin user for the virtual machine')
param adminUsername string

@description('Password for the admin user of the virtual machine')
@secure()
param adminPassword string

@description('ID of the subnet to which the VM will be connected')
param subnetId string

resource nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize 
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmId string = virtualMachine.id
