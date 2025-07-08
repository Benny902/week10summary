#!/bin/bash

# Define variables
RESOURCE_GROUP="dev-devops-week10-rg"
VM_NAME="week10vm"

# Get the public IP of the VM using Azure CLI
VM_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  -d \
  --query publicIps \
  -o tsv)

APP_URL="http://${VM_IP}:3000"

echo "Checking $APP_URL..."
if curl --fail --silent "$APP_URL"; then
  echo "App is healthy!"
  exit 0
else
  echo "App is unreachable!"
  exit 1
fi
