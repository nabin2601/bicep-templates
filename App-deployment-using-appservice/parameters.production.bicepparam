using './main.bicep'

param appName = 'myapp'
param location = 'australiaeast'
param appServicePlanSku = 'S1'
param appServiceInstanceCount = 2
param sqlDatabaseSku = 'Standard'
param sqlAdminUsername = 'dbadmin'
param sqlAdminPassword = 'SqlAdminPassword'
param frontDoorSku = 'Premium_AzureFrontDoor'
param enableWaf = true
param environment = 'production'
