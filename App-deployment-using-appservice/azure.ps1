Connect-AzAccount

New-AzResourceGroupDeployment -ResourceGroupName "<RESOURCE_GROUP_NAME>" -TemplateFile "main.bicep" -TemplateParameterFile "<TEMPLATE_PARAMETER_FILE>"