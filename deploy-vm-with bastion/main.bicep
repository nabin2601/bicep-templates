@description('The azure region to deploy the resources to.')
param location string = resourceGroup().location

@secure()
@description('The password for the admin user of the virtual machine.')
param adminPassword string

@secure()
@description('the username for the admin user of the virtual machine.')
param adminUsername string

@allowed([
    'Standard_B1s'
    'Standard_B2s'
    'Standard_B4ms'
    'Standard_B8ms'
])
@description('The size of the virtual machine.')
param vmSize string = 'Standard_B1s'

@minLength(3)
@maxLength(15)
@description('The name of the virtual machine.')
param vmName string = 'vm${uniqueString(resourceGroup().id)}'

@description('vnet name for the virtual machine.')
param vnetName string = 'vnet${uniqueString(resourceGroup().id)}'

@description('the nic name for the virtual machine.')
param nicName string = 'nic${uniqueString(resourceGroup().id)}'

@description('the bastion name for the virtual machine.')
param bastionName string = 'bastion${uniqueString(resourceGroup().id)}'

@description('the public ip name for the virtual machine.')
param publicIpName string = 'publicIp${uniqueString(resourceGroup().id)}'


resource publicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: publicIpName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: vnet  
  name: '${vmName}prod-subnet'
  properties: {
    addressPrefix: '192.168.1.0/24'
  }
}
resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: vnet  
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: '192.168.0.0/27'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2025-05-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetBastion.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
  sku:{
    name: 'Basic'
    }
}
resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
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
        createOption: 'FromImage'
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

output bastionHostName string = bastion.name
output publicIpAddress string = publicIp.properties.ipAddress
output virtualMachineName string = vm.name
output ventName string = vnet.name
output subnetName string = subnet.name
output nicName string = nic.name
