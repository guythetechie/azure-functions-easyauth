# azure-functions-easyauth

## Overview

This repository contains a simple HTTP-triggered function that echoes incoming request headers as JSON. It also includes a Bicep template that provisions the Function App, its associated resources, and configures it with EAsy Auth.
## Test the function

### Bash

```bash
# Replace with your actual function app name
FUNCTION_APP_NAME="easy-auth-fn-xxxx-function-app"

# Unauthenticated request
curl -i "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/HelloWorld"
# Expected: 401 Unauthorized response

# Authenticated request
TOKEN=$(az account get-access-token --query accessToken --output tsv)
curl -i -H "Authorization: Bearer $TOKEN" \
  "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/HelloWorld"
# Expected: 200 OK with JSON response including Easy Auth headers:
# X-MS-CLIENT-PRINCIPAL, X-MS-CLIENT-PRINCIPAL-NAME, X-MS-CLIENT-PRINCIPAL-ID, X-MS-TOKEN-AAD-ID-TOKEN
```

### PowerShell

```powershell
# Replace with your actual function app name
$FunctionAppName = "easy-auth-fn-xxxx-function-app"

# Unauthenticated request
try {
    Invoke-RestMethod -Uri "https://$FunctionAppName.azurewebsites.net/api/HelloWorld" -Method Get
} catch {
    Write-Host "Expected 401 Unauthorized: $($_.Exception.Message)"
}

# Authenticated request
$Token = (Get-AzAccessToken).Token
$Headers = @{ Authorization = "Bearer $Token" }
Invoke-RestMethod -Uri "https://$FunctionAppName.azurewebsites.net/api/HelloWorld" -Method Get -Headers $Headers
# Expected: JSON response with Easy Auth headers:
# X-MS-CLIENT-PRINCIPAL, X-MS-CLIENT-PRINCIPAL-NAME, X-MS-CLIENT-PRINCIPAL-ID, X-MS-TOKEN-AAD-ID-TOKEN
```


## Files of interest

- `src/function/HelloWorld.cs` — the HTTP-triggered function that returns request headers.
- `bicep/main.bicep` — infra template that creates the Function App, managed identity, app registration and configures Easy Auth (authsettingsV2).
- `deploy.sh` — convenience script to deploy the Bicep template using the Azure CLI.


## License

No license is specified in this repository.
