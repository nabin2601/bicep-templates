// ============================================================
//  Module: networking
//  Creates: VNet, VM subnet, Bastion subnet, Bastion host,
//           and the Bastion public IP.
// ============================================================

@description('Azure region to deploy the resources to.')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Address prefix for the virtual network')
param vnetAddressPrefix string

@description('Name of the Bastion host')
param bastionHostName string

@description('Name of the Bastion public IP')
param bastionPublicIpName string

@description('Address prefix for the Bastion subnet')
param bastionSubnetAddressPrefix string

@description('Address prefix for the VM subnet')
param vmSubnetAddressPrefix string

// Virtual Network

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

//Public IP

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: bastionPublicIpName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
      name: 'Standard'
      tier: 'Regional'
  }
}

//Bastion Subnet

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: vnet  
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetAddressPrefix
  }
}

//VM Subnet
resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: vnet  
  name: 'vmSubnet'
  properties: {
    addressPrefix: vmSubnetAddressPrefix
  }
}

//Bastion Host

resource bastionHost 'Microsoft.Network/bastionHosts@2025-05-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionHostIpConfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vmSubnetId string = vmSubnet.id
output bastionSubnetId string = bastionSubnet.id
output bastionHostName string = bastionHost.name
