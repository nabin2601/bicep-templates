using './main.bicep'

param appName = 'myapp-dev'
param location = 'australiaeast'
param appServicePlanSku = 'S1'
param appServiceInstanceCount = 1
param sqlDatabaseSku = 'Basic'
param sqlAdminUsername = 'dbadmin'
param sqlAdminPassword = 'REPLACE_WITH_SECURE_PASSWORD_OR_USE_KEYVAULT_REFERENCE'
param frontDoorSku = 'Standard_AzureFrontDoor'
param enableWaf = false
param environment = 'development'
