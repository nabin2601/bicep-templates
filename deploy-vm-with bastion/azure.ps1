Connect-AzAccount

New-AzResourceGroupDeployment -ResourceGroupName '<resourceGroupName>' -TemplateFile main.bicep


Disconnect-AzAccount
