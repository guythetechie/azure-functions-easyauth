#!/bin/bash

RESOURCE_GROUP_NAME="easy-auth-fn-rg"
LOCATION="eastus2"

echo "Login to Azure if the user is not already logged in..."
if [ -z "$(az account show --query 'id' --output tsv)" ]; then
    az login --use-device-code
fi

echo "Deploying resources..."
if [ -z "$(az group show --name "$RESOURCE_GROUP_NAME" --query 'id' --output tsv)" ]; then
  az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
fi

echo "Creating Bicep deployment..."
az deployment group create \
    --name "easy-auth-fn-deployment" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "./bicep/main.bicep" \
    --parameters location="$LOCATION"