# Azure VM with Bastion Host

This template deploys an Azure Virtual Machine with a Bastion Host for secure, browser-based RDP/SSH access without exposing a public IP on the VM.

## Resources Deployed

| Resource | Description |
|---|---|
| Virtual Network | VNet with a `192.168.0.0/16` address space |
| VM Subnet | `192.168.1.0/24` — hosts the VM's NIC |
| AzureBastionSubnet | `192.168.0.0/27` — dedicated subnet required by Bastion |
| Network Interface | NIC attached to the VM subnet |
| Public IP Address | Standard SKU, Static — required by Bastion |
| Bastion Host | Basic SKU, provides secure browser-based access to the VM |
| Virtual Machine | Windows Server 2019 Datacenter |

## Architecture

```
VNet (192.168.0.0/16)
├── AzureBastionSubnet (192.168.0.0/27)
│   └── Bastion Host ── Standard Public IP
└── prod-subnet (192.168.1.0/24)
    └── NIC ── Windows Server 2019 VM
```

## Prerequisites

- Azure CLI or Azure PowerShell installed
- An active Azure subscription
- Contributor access on the target resource group

## Deployment

### Azure CLI

```bash
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file main.bicep 
```

### Azure PowerShell

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName "<your-resource-group>" `
  -TemplateFile "./main.bicep"
```

## Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `location` | string | No | Resource group location | Azure region for all resources |
| `adminUsername` | string | **Yes** | — | Admin username for the VM |
| `adminPassword` | string | **Yes** | — | Admin password for the VM |
| `vmSize` | string | No | `Standard_B1s` | VM size (`Standard_B1s`, `Standard_B2s`, `Standard_B4ms`, `Standard_B8ms`) |
| `vmName` | string | No | `vm<uniqueString>` | Name of the VM (3–15 chars) |
| `vnetName` | string | No | `vnet<uniqueString>` | Name of the virtual network |
| `nicName` | string | No | `nic<uniqueString>` | Name of the network interface |
| `bastionName` | string | No | `bastion<uniqueString>` | Name of the Bastion host |
| `publicIpName` | string | No | `publicIp<uniqueString>` | Name of the public IP address |

## Outputs

| Output | Description |
|---|---|
| `bastionHostName` | Name of the deployed Bastion host |
| `publicIpAddress` | Public IP address of the Bastion host |
| `virtualMachineName` | Name of the deployed VM |
| `vnetName` | Name of the virtual network |
| `subnetName` | Name of the VM subnet |
| `nicName` | Name of the network interface |

## Connecting to the VM

1. Navigate to the VM in the [Azure Portal](https://portal.azure.com)
2. Click **Connect** → **Bastion**
3. Enter your VM credentials
4. Click **Connect** — a browser-based session will open

> No public IP is required on the VM. All access is routed securely through the Bastion host.

## Notes

- The `AzureBastionSubnet` must be at least `/27` for the Basic SKU
- The public IP must be **Standard SKU** and **Static** allocation — Bastion does not support Basic or Dynamic IPs
- Bastion provides RDP and SSH access without requiring any open inbound ports on the VM
