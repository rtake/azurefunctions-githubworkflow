#!/usr/bin/env bash

readonly SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID is required}"
readonly AIFOUNDRY_ACCOUNT_NAME="${AIFOUNDRY_ACCOUNT_NAME:?AIFOUNDRY_ACCOUNT_NAME is required}"
readonly RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:?RESOURCE_GROUP_NAME is required}"
readonly PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME is required}"
readonly MODEL_CONFIG_FILE="${MODEL_CONFIG_FILE:-azure/infra/model-config.json}"

foundry_base_url() {
  printf 'https://%s.services.ai.azure.com' "$AIFOUNDRY_ACCOUNT_NAME"
}

arm_base_url() {
  printf 'https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.CognitiveServices/accounts/%s/projects/%s' \
    "$SUBSCRIPTION_ID" \
    "$RESOURCE_GROUP_NAME" \
    "$AIFOUNDRY_ACCOUNT_NAME" \
    "$PROJECT_NAME"
}

application_url() {
  local app_name="$1"
  printf '%s/applications/%s?api-version=2025-10-01-preview' "$(arm_base_url)" "$app_name"
}

deployment_url() {
  local app_name="$1"
  printf '%s/applications/%s/agentDeployments/%s?api-version=2025-10-01-preview' "$(arm_base_url)" "$app_name" "$app_name"
}

fallback_deployment_id() {
  local app_name="$1"
  local deployment_name="$2"
  printf '/subscriptions/%s/resourceGroups/%s/providers/Microsoft.CognitiveServices/accounts/%s/projects/%s/applications/%s/agentDeployments/%s' \
    "$SUBSCRIPTION_ID" \
    "$RESOURCE_GROUP_NAME" \
    "$AIFOUNDRY_ACCOUNT_NAME" \
    "$PROJECT_NAME" \
    "$app_name" \
    "$deployment_name"
}
