Connect-AzAccount

$bicepparampath = '<parameter file path>/main.bicepparam'
New-AzResourceGroupDeployment -ResourceGroupName '<resource-group-name>' -TemplateFile main.bicep -TemplateParameterFile $bicepparampath  -WhatIf