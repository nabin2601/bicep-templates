# Azure Multi-VM Deployment with Backup

Deploys any number of Windows Server 2019 VMs into a shared virtual network, secures remote access via Azure Bastion, and automatically enrolls each VM into a Recovery Services Vault with a daily backup policy.

---

## File Structure

```
main.bicep                   ← Entry point — orchestrates all modules
main.bicepparam              ← Parameter values (one file per environment)
modules/
  networking.bicep           ← VNet, subnets, Bastion host, public IP
  storage.bicep              ← Storage account for boot diagnostics
  virtualmachine.bicep       ← NIC + VM (looped once per vmConfigs entry)
  backup.bicep               ← Recovery Vault, backup policy, protected items
```

---

## Architecture

```
Resource Group
├── Virtual Network (192.168.0.0/16)
│   ├── vm-subnet          (192.168.1.0/24)  ← NICs for all VMs
│   └── AzureBastionSubnet (192.168.0.0/26)  ← Bastion only
│
├── Azure Bastion + Public IP                 ← Secure RDP, no public VM IPs
│
├── Storage Account                           ← Boot diagnostics for all VMs
│
├── VM 1  (NIC → vm-subnet)
├── VM 2  (NIC → vm-subnet)
└── VM N  ...
│
└── Recovery Services Vault
    ├── DailyVMPolicy  (configurable schedule + retention)
    ├── Protected item → VM 1
    ├── Protected item → VM 2
    └── Protected item → VM N  (skipped if enableBackup: false)
```

---

## Prerequisites

- [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) module installed (`Az` module v10+)
- Signed in to Azure:
  ```powershell
  Connect-AzAccount
  ```
- An existing Resource Group, or create one:
  ```powershell
  New-AzResourceGroup -Name 'my-rg' -Location 'australiaeast'
  ```
- Bicep CLI v0.25 or later. Install or update via:
  ```powershell
  az bicep install
  # or update an existing install
  az bicep upgrade
  ```

---

## Quick Start

Deploy using inline parameters (useful for one-off or testing deployments):

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName 'my-rg' `
  -TemplateFile './main.bicep' `
  -adminUsername 'azureuser' `
  -adminPassword (ConvertTo-SecureString 'YourStr0ngP@ss!' -AsPlainText -Force)
```

> Note: `adminPassword` must be passed as a `SecureString` — Azure PowerShell enforces this for all `@secure()` parameters.

This deploys the defaults: **two VMs** (`vm-001`, `vm-002`), both backed up daily at 02:00 UTC with a 7-day retention.

---

## Parameters

### `main.bicep` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | string | Resource group location | Azure region for all resources |
| `adminUsername` | securestring | *(required)* | Admin username for all VMs |
| `adminPassword` | securestring | *(required)* | Admin password for all VMs |
| `defaultVmSize` | string | `Standard_B2s` | Fallback VM size when a vmConfigs entry omits `vmSize` |
| `vmConfigs` | array | `[{vmName:'vm-001'},{vmName:'vm-002'}]` | VM definitions (see below) |
| `vnetName` | string | `vnet-<hash>` | Name of the virtual network |
| `vnetAddressPrefix` | string | `192.168.0.0/16` | Address space for the virtual network |
| `vmSubnetAddressPrefix` | string | `192.168.1.0/24` | Address prefix for the VM subnet |
| `bastionHostName` | string | `bastion-<hash>` | Name of the Bastion host |
| `bastionPublicIpName` | string | `pip-bastion-<hash>` | Name of the Bastion public IP |
| `bastionSubnetAddressPrefix` | string | `192.168.0.0/26` | Address prefix for AzureBastionSubnet (min /26) |
| `storageAccountName` | string | `sa<hash>` | Name of the boot diagnostics storage account |
| `vaultName` | string | `rsv-<hash>` | Name of the Recovery Services Vault |
| `backupTime` | string | `2025-01-01T02:00:00Z` | Daily backup window (UTC) |
| `retentionDays` | int | `7` | Days to retain daily recovery points (1–365) |

### `vmConfigs` array

Each entry supports three fields:

| Field | Required | Description |
|---|---|---|
| `vmName` | Yes | VM name — 3 to 15 characters, used for the VM, NIC, and OS disk |
| `vmSize` | No | VM SKU — overrides `defaultVmSize` for this VM only |
| `enableBackup` | No | Set to `false` to skip backup registration (default: `true`) |

**Example:**
```bicep
param vmConfigs = [
  { vmName: 'web01' }
  { vmName: 'app01', vmSize: 'Standard_B4ms' }
  { vmName: 'db01',  vmSize: 'Standard_B4ms', enableBackup: false }
]
```

---

## Deploying with a Parameters File

For repeatable or environment-specific deployments, use `main.bicepparam` alongside `main.bicep`.
See the included `main.bicepparam` for a fully commented example.

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName 'my-rg' `
  -TemplateFile './main.bicep' `
  -TemplateParameterFile './main.bicepparam'
```

To target a different environment, swap the parameter file:

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName 'my-prod-rg' `
  -TemplateFile './main.bicep' `
  -TemplateParameterFile './main.prod.bicepparam'
```

> **Tip:** Never commit plain-text passwords to source control. Use `az.getSecret()` in your `.bicepparam` file to pull credentials from Azure Key Vault at deploy time.

---

## Outputs

After a successful deployment the following values are returned:

| Output | Description |
|---|---|
| `bastionHostName` | Name of the deployed Bastion host |
| `bastionPublicIp` | Public IP address assigned to Bastion |
| `vaultName` | Name of the Recovery Services Vault |
| `backupPolicyName` | Name of the backup policy (`DailyVMPolicy`) |
| `storageAccount` | Name of the boot diagnostics storage account |
| `deployedVMs` | Array of `{ vmName, nicName, backupEnabled }` for each VM |

Retrieve outputs at any time with:

```powershell
(Get-AzResourceGroupDeployment `
  -ResourceGroupName 'my-rg' `
  -Name 'main').Outputs
```

To extract a single value:

```powershell
(Get-AzResourceGroupDeployment `
  -ResourceGroupName 'my-rg' `
  -Name 'main').Outputs['bastionPublicIp'].Value
```

---

## Connecting to a VM via Bastion

No VM has a public IP — access is exclusively through Bastion:

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to **Virtual Machines → \<vm-name\> → Connect → Bastion**
3. Enter the `adminUsername` and `adminPassword` used during deployment

---

## Allowed VM Sizes

The `defaultVmSize` parameter (and per-VM `vmSize` field) is restricted to:

| SKU | vCPUs | RAM |
|---|---|---|
| `Standard_B1s` | 1 | 1 GB |
| `Standard_B2s` | 2 | 4 GB |
| `Standard_B4ms` | 4 | 16 GB |
| `Standard_B8ms` | 8 | 32 GB |

To allow additional sizes, add them to the `@allowed` decorator in both `main.bicep` and `modules/virtualmachine.bicep`.

---

## Backup Policy Details

| Setting | Value |
|---|---|
| Type | Azure IaaS VM (agent-based) |
| Frequency | Daily |
| Schedule | Configurable via `backupTime` (default 02:00 UTC) |
| Instant restore retention | 2 days |
| Daily retention | Configurable via `retentionDays` (default 7, max 365) |

To opt a VM out of backup, set `enableBackup: false` in its `vmConfigs` entry.

---

## Tearing Down

```powershell
Remove-AzResourceGroup -Name 'my-rg' -Force
```

This removes all resources in the group including the vault and its backup data.

> **Warning:** If the Recovery Services Vault holds active backup data, the deletion will fail. You must first stop protection and delete backup data for each VM before removing the resource group, or use the portal to force-delete the vault.

To stop protection and delete backup data for a VM before tear-down:

```powershell
$vault = Get-AzRecoveryServicesVault -ResourceGroupName 'my-rg'
Set-AzRecoveryServicesVaultContext -Vault $vault

$container = Get-AzRecoveryServicesBackupContainer `
  -ContainerType AzureVM `
  -VaultId $vault.ID

$item = Get-AzRecoveryServicesBackupItem `
  -Container $container `
  -WorkloadType AzureVM `
  -VaultId $vault.ID

Disable-AzRecoveryServicesBackupProtection `
  -Item $item `
  -RemoveRecoveryPoints `
  -VaultId $vault.ID `
  -Force
```

Run the above for each VM, then remove the resource group.

