// ============================================================================
// MODULE: Front Door & WAF
// Resources: Front Door Profile, Endpoint, Origin Group, Origin, Route,
//            WAF Policy (conditional)
// ============================================================================

@description('The name of the application.')
param appName string

@description('Environment tag for resources.')
param environment string

@description('Front Door SKU - Standard or Premium (Premium required for full WAF).')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSku string

@description('Enable WAF on Front Door. Requires Premium SKU.')
param enableWaf bool

@description('The backend hostname of the App Service (production slot).')
param appServiceHostName string

// ============================================================================
// VARIABLES
// ============================================================================

var frontDoorProfileName = 'afd-${appName}'
var frontDoorEndpointName = '${appName}-endpoint'
var wafPolicyName = 'waf${replace(appName, '-', '')}'

// ============================================================================
// RESOURCE: Front Door Profile
// ============================================================================

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSku
  }
  tags: {
    environment: environment
    app: appName
  }
}

// ============================================================================
// RESOURCE: Front Door Endpoint
// ============================================================================

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  parent: frontDoorProfile
  name: frontDoorEndpointName
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// ============================================================================
// RESOURCE: Front Door Origin Group
// ============================================================================

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  parent: frontDoorProfile
  name: 'origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// ============================================================================
// RESOURCE: Front Door Origin (App Service)
// ============================================================================

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  parent: originGroup
  name: 'app-service-origin'
  properties: {
    hostName: appServiceHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: appServiceHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

// ============================================================================
// RESOURCE: Front Door Route
// ============================================================================

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  dependsOn: [
    origin
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

// ============================================================================
// RESOURCE: WAF Policy (only when enableWaf=true AND Premium SKU)
// ============================================================================

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2021-06-01' = if (enableWaf && frontDoorSku == 'Premium_AzureFrontDoor') {
  name: wafPolicyName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection' // Change to 'Prevention' after initial testing
      redirectUrl: ''
      customBlockResponseStatusCode: 403
      customBlockResponseBody: base64('Access denied by WAF')
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
    }
    customRules: {
      rules: []
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The Front Door endpoint hostname.')
output frontDoorHostName string = frontDoorEndpoint.properties.hostName

@description('The Front Door profile resource ID.')
output frontDoorProfileId string = frontDoorProfile.id
