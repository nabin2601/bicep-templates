using './main.bicep'

// ── Credentials ─────────────────────────────────────────────
// Use az.getSecret() to pull from Key Vault and keep secrets
// out of source control. Replace the three placeholder values.

param adminUsername = az.getSecret(
  '<subscription-id>',
  '<keyvault-resource-group>',
  '<keyvault-name>',
  'vm-admin-username'
)

param adminPassword = az.getSecret(
  '<subscription-id>',
  '<keyvault-resource-group>',
  '<keyvault-name>',
  'vm-admin-password'
)


// ── VM fleet ────────────────────────────────────────────────
// defaultVmSize applies to any entry that omits vmSize.
// Allowed values: Standard_B1s | Standard_B2s | Standard_B4ms | Standard_B8ms

param defaultVmSize = 'Standard_B2s'

// Each entry supports:
//   vmName       (required) 3–15 chars
//   vmSize       (optional) overrides defaultVmSize for this VM only
//   enableBackup (optional) false = skip backup registration; default true

param vmConfigs = [
  {
    vmName: 'vm01'
  }
  {
    vmName: 'vm02'
    vmSize: 'Standard_B2s'
  }
]

// ── Networking ──────────────────────────────────────────────

param vnetName                  = 'vnet-prod-aue'
param vnetAddressPrefix         = '192.168.0.0/16'
param vmSubnetAddressPrefix     = '192.168.1.0/24'
param bastionHostName           = 'bastion-prod-aue'
param bastionPublicIpName       = 'pip-bastion-prod-aue'
param bastionSubnetAddressPrefix = '192.168.0.0/27'

// ── Storage ─────────────────────────────────────────────────
// storage account gets unique name from main.bicep file

// ── Backup ──────────────────────────────────────────────────

param vaultName     = 'rsv-prod-aue'
param backupTime    = '2026-04-02T23:00:00Z'  // UTC daily backup window
param retentionDays = 7                     // 1–365
