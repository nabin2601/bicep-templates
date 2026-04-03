Connect-AzAccount

New-AzResourceGroupDeployment -ResourceGroupName '1-6991945e-playground-sandbox' -TemplateFile main.bicep


Disconnect-AzAccount