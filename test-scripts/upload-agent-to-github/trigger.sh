#!/usr/bin/env bash

set -a
source .env
set +a

payload=$(jq -n \
  --arg subscriptionId "$SUBSCRIPTION_ID" \
  --arg resourceGroup "$RESOURCE_GROUP" \
  --arg accountName "$ACCOUNT_NAME" \
  --arg projectName "$PROJECT_NAME" \
  --arg appName "$APP_NAME" \
  --arg deploymentName "$DEPLOYMENT_NAME" \
  '{
    subscriptionId: $subscriptionId,
    resourceGroup: $resourceGroup,
    accountName: $accountName,
    projectName: $projectName,
    appName: $appName,
    deploymentName: $deploymentName
  }')

curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "x-functions-key: $FUNCTION_KEY" \
  -d "$payload"