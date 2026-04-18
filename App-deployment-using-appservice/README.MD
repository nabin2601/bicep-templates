# Azure Infrastructure — Bicep IaC

A modular Azure infrastructure deployment using [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview), provisioning a production-ready Node.js web application stack with Front Door, WAF, SQL Database, Redis Cache, Key Vault, Storage, and full observability.

---

## Architecture Overview

```
Internet
   │
   ▼
Azure Front Door (CDN + WAF)
   │
   ▼
App Service (Production Slot)
   │        └── Dev Deployment Slot
   │
   ├── Azure SQL Database
   ├── Azure Cache for Redis
   ├── Azure Storage Account
   ├── Azure Key Vault
   └── Application Insights → Log Analytics Workspace
```

All traffic to the App Service is restricted to the `AzureFrontDoor.Backend` service tag — direct access is denied.

---

## Repository Structure

```
├── main.bicep                          # Orchestrator — wires all modules together
├── parameters_development.bicepparam   # Development environment parameters
├── parameters_production.bicepparam    # Production environment parameters
├── azure.ps1                           # PowerShell deployment helper script
└── modules/
    ├── appservice.bicep                # App Service Plan, Web App, Dev slot, Diagnostics
    ├── database.bicep                  # SQL Server, SQL Database, Redis Cache
    ├── frontdoor-waf.bicep             # Front Door Profile, Endpoint, Route, WAF Policy
    ├── monitoring.bicep                # Log Analytics Workspace, Application Insights
    └── storage-keyvault.bicep          # Storage Account, Key Vault, SQL connection secret
```

---

## Resources Deployed

| Module | Resources |
|---|---|
| `monitoring.bicep` | Log Analytics Workspace, Application Insights |
| `appservice.bicep` | App Service Plan, Web App (production slot), Dev deployment slot, Diagnostic settings |
| `database.bicep` | Azure SQL Server, SQL Database, Firewall rule, Azure Cache for Redis |
| `storage-keyvault.bicep` | Storage Account (Standard LRS), Key Vault, SQL connection string secret |
| `frontdoor-waf.bicep` | Front Door Profile, Endpoint, Origin Group, Route, WAF Policy (Premium only) |

---

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) or [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) v0.15+
- An existing Azure Resource Group
- Sufficient permissions to create resources in the target subscription

---

## Deployment

### Option 1 — Azure CLI

```bash
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file main.bicep \
  --parameters @parameters_production.bicepparam
```

For development:

```bash
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file main.bicep \
  --parameters @parameters_development.bicepparam
```

### Option 2 — Azure PowerShell (`azure.ps1`)

```powershell
Connect-AzAccount

New-AzResourceGroupDeployment `
  -ResourceGroupName "<your-resource-group>" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "parameters_production.bicepparam"
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `appName` | string | `myapp` | Application name. Must be globally unique (1–30 chars). |
| `location` | string | Resource group location | Azure region for all resources. |
| `appServicePlanSku` | string | `S1` | App Service Plan SKU. Allowed: `S1`, `S2`, `S3`, `P1v2`, `P2v2`, `P3v2`. |
| `appServiceInstanceCount` | int | `1` | Number of App Service instances (1–10). |
| `sqlDatabaseSku` | string | `Standard` | SQL Database tier. Allowed: `Basic`, `Standard`, `Premium`. |
| `sqlAdminUsername` | string | `dbadmin` | SQL Server administrator username. |
| `sqlAdminPassword` | securestring | *(required)* | SQL Server administrator password. **Never commit this value.** |
| `frontDoorSku` | string | `Premium_AzureFrontDoor` | Front Door SKU. `Premium_AzureFrontDoor` is required to enable WAF. |
| `enableWaf` | bool | `true` | Enable WAF on Front Door. Requires `Premium_AzureFrontDoor` SKU. |
| `environment` | string | `production` | Environment tag applied to all resources. |

### Environment Configurations

| Setting | Development | Production |
|---|---|---|
| `appName` | `myapp-dev` | `myapp` |
| `location` | `australiaeast` | `australiaeast` |
| `appServicePlanSku` | `S1` | `S1` |
| `appServiceInstanceCount` | `1` | `2` |
| `sqlDatabaseSku` | `Basic` | `Standard` |
| `frontDoorSku` | `Standard_AzureFrontDoor` | `Premium_AzureFrontDoor` |
| `enableWaf` | `false` | `true` |

---

## Outputs

After a successful deployment the following values are emitted:

| Output | Description |
|---|---|
| `appServiceHostName` | App Service production hostname |
| `devSlotHostName` | Dev deployment slot hostname |
| `frontDoorHostName` | Azure Front Door endpoint hostname |
| `sqlServerFqdn` | SQL Server fully qualified domain name |
| `sqlDatabaseName` | SQL Database name |
| `redisCacheHostName` | Redis Cache hostname |
| `storageAccountName` | Storage Account name |
| `keyVaultUri` | Key Vault URI |
| `logAnalyticsWorkspaceId` | Log Analytics Workspace resource ID |
| `appInsightsInstrumentationKey` | Application Insights instrumentation key |
| `resourceGroupId` | Resource Group resource ID |

---

## Security Notes

- **Secrets**: The `sqlAdminPassword` parameter is marked `@secure()` and is never logged or surfaced in deployment outputs. Use a Key Vault reference or a CI/CD secret store — never hardcode it in a `.bicepparam` file.
- **Network access**: The App Service only accepts traffic from `AzureFrontDoor.Backend`. All other inbound traffic is explicitly denied via IP security restrictions.
- **WAF**: When `enableWaf = true` and the Premium SKU is selected, the WAF is deployed in **Detection** mode by default. Switch to `Prevention` mode after validating that no legitimate traffic is being flagged.
- **TLS**: All resources enforce a minimum of TLS 1.2. FTPS is disabled on the App Service.
- **Key Vault access**: The Web App's system-assigned managed identity is granted `get` and `list` permissions on Key Vault secrets — no credentials are stored in application config.
- **Storage**: The Storage Account enforces HTTPS-only traffic and TLS 1.2 as the minimum version.

---

## Monitoring

- **Log Analytics Workspace** — 30-day retention, PerGB2018 pricing tier.
- **Application Insights** — linked to the Log Analytics Workspace; connection string is injected into the App Service as an app setting (`APPLICATIONINSIGHTS_CONNECTION_STRING`).
- **Diagnostic settings** — `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, and `AppServiceAppLogs` are all forwarded to Log Analytics (30-day retention). All metrics are retained for 7 days.

---

## Naming Conventions

Resources that require globally unique names use a `uniqueString(resourceGroup().id)` suffix to avoid collisions:

| Resource | Name Pattern |
|---|---|
| Web App | `<appName>-<uniqueSuffix>` |
| SQL Server | `sqlserver-<appName>-<uniqueSuffix>` |
| Redis Cache | `cache-<appName>-<uniqueSuffix>` |
| Storage Account | `storage<appName><uniqueSuffix>` |
| Key Vault | `kv-<uniqueSuffix>` |
| App Insights | `appinsights-<appName>` |
| Log Analytics | `logs-<appName>` |
| Front Door | `afd-<appName>` |
