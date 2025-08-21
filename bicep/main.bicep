extension microsoftGraphV1

param location string = 'eastus2'
var prefix = 'easy-auth-fn-${take(uniqueString(resourceGroup().id),4)}'

var roleDefinitions = {
  'Storage Blob Data Owner': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  )
  'Storage Table Data Contributor': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  )
}

var environmentAudiences = {
  AzureCloud: 'api://AzureADTokenExchange'
  AzureUSGovernment: 'api://AzureADTokenExchangeUSGov'
  AzureChinaCloud: 'api://AzureADTokenExchangeChina'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: '${prefix}-log-analytics-workspace'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-application-insights'
  location: location
  kind: 'other'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: '${prefix}-app-service-plan'
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: '${replace(prefix, '-', '')}stor'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource functionAppContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  name: 'function-app'
  parent: blobServices
  properties: {
    publicAccess: 'None'
  }
}

resource blobServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: blobServices
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource tableServices 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource tableServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: tableServices
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource functionAppStorageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionName in [
    'Storage Blob Data Owner'
    'Storage Table Data Contributor'
  ]: {
    name: guid(storageAccount.id, roleDefinitionName, functionApp.id)
    scope: storageAccount
    properties: {
      roleDefinitionId: roleDefinitions[roleDefinitionName]
      principalId: functionAppManagedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource functionAppManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${prefix}-function-app-managed-identity'
  location: location
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: '${prefix}-function-app'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionAppManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: storageAccount.properties.primaryEndpoints.table
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
          value: functionAppManagedIdentity.properties.clientId
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: uri(storageAccount.properties.primaryEndpoints.blob, functionAppContainer.name)
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: functionAppManagedIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '9.0'
      }
    }
  }
}

resource functionAppAuthSettings 'Microsoft.Web/sites/config@2024-11-01' = {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    globalValidation: {
      requireAuthentication: true
      redirectToProvider: 'azureActiveDirectory'
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: appRegistration.appId
          clientSecretSettingName: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
          openIdIssuer: federatedIdentityCredential.issuer
        }
      }
    }
  }
}

resource functionAppDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: functionApp
  properties: {
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuthenticationLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource appRegistration 'Microsoft.Graph/applications@v1.0' = {
  displayName: prefix
  uniqueName: prefix
  signInAudience: 'AzureADMyOrg'
  web: {
    implicitGrantSettings: {
      enableIdTokenIssuance: true
    }
  }
}

resource federatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${appRegistration.uniqueName}/${functionAppManagedIdentity.name}'
  audiences: [
    environmentAudiences[environment().name]
  ]
  issuer: '${environment().authentication.loginEndpoint}${functionAppManagedIdentity.properties.tenantId}/v2.0'
  subject: functionAppManagedIdentity.properties.principalId
}
