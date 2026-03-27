#!/usr/bin/env bash

collect_agents() {
  local files="${FILES:-}"
  local foundry_token="${FOUNDRY_TOKEN:?FOUNDRY_TOKEN is required}"
  local agents_json

  agents_json=$(jq -cn '[]')

  while IFS= read -r agent_file; do
    [ -z "$agent_file" ] && continue

    local agent_name get_url get_response status agent_response
    local agent_id agent_version safe_agent_version deployment_name agent_state model_name model_config
    local configured_deployment_name model_format model_version model_publisher sku_name sku_capacity deployment_state service_tier version_upgrade_option

    agent_name=$(agent_file_to_name "$agent_file")
    model_name=$(jq -r '.model // empty' "$agent_file")
    if [ -z "$model_name" ] || [ "$model_name" = "null" ]; then
      echo "Missing model in ${agent_file}"
      exit 1
    fi

    model_config=$(resolve_model_config "$model_name")
    configured_deployment_name=$(agent_field "$model_config" "deploymentName")
    model_name=$(agent_field "$model_config" "modelName")
    model_format=$(agent_field "$model_config" "modelFormat")
    model_version=$(agent_field "$model_config" "modelVersion")
    model_publisher=$(agent_field "$model_config" "modelPublisher")
    sku_name=$(agent_field "$model_config" "skuName")
    sku_capacity=$(agent_field "$model_config" "skuCapacity")
    deployment_state=$(agent_field "$model_config" "deploymentState")
    service_tier=$(agent_field "$model_config" "serviceTier")
    version_upgrade_option=$(agent_field "$model_config" "versionUpgradeOption")

    echo "=== Processing ${agent_name} ==="

    get_url="$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents/${agent_name}?api-version=v1"
    get_response=$(get_json_with_status "$get_url" "$foundry_token")
    status="${get_response: -3}"
    agent_response="${get_response%???}"

    if [ "$status" = "404" ]; then
      echo "Creating agent ${PROJECT_NAME}/${agent_name}"
      agent_response=$(post_json \
        "$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents?api-version=v1" \
        "$foundry_token" \
        "$(build_agent_create_body "$agent_name" "$agent_file")")
    elif [ "$status" = "200" ]; then
      echo "Updating agent ${PROJECT_NAME}/${agent_name}"
      agent_response=$(post_json \
        "$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents/${agent_name}?api-version=v1" \
        "$foundry_token" \
        "$(build_agent_update_body "$agent_file")")
    else
      echo "Failed to check existing agent ${PROJECT_NAME}/${agent_name}: HTTP ${status}"
      [ -n "$agent_response" ] && echo "$agent_response"
      exit 1
    fi

    log_response "Agent response" "$agent_response"

    agent_id=$(require_json_field "$agent_response" '.id' "Failed to resolve agent id")
    agent_version=$(require_json_field "$agent_response" '.versions.latest.version' "Failed to resolve agent version")
    safe_agent_version=$(printf '%s' "$agent_version" | tr -c '[:alnum:]-' '-')
    deployment_name="${agent_name}-v-${safe_agent_version}"

    agent_state=$(build_agent_state \
      "$agent_name" \
      "$agent_file" \
      "$agent_id" \
      "$agent_version" \
      "$deployment_name" \
      "$configured_deployment_name" \
      "$model_name" \
      "$model_format" \
      "$model_version" \
      "$model_publisher" \
      "$sku_name" \
      "$sku_capacity" \
      "$deployment_state" \
      "$service_tier" \
      "$version_upgrade_option")

    agents_json=$(append_agent "$agents_json" "$agent_state")
  done <<< "$files"

  write_output_json "agents" "$agents_json"
}

deploy_models() {
  local agents="${AGENTS:?AGENTS is required}"
  local missing_models

  missing_models=$(jq -c '
    map({
      deploymentName: .modelDeploymentName,
      modelName: .modelName,
      modelFormat: .modelFormat,
      modelVersion: .modelVersion,
      modelPublisher: .modelPublisher,
      skuName: .skuName,
      skuCapacity: .skuCapacity,
      deploymentState: .deploymentState,
      serviceTier: .serviceTier,
      versionUpgradeOption: .versionUpgradeOption
    })
    | unique_by(.deploymentName)
  ' <<< "$agents")

  while IFS= read -r model; do
    local deployment_name model_name model_format model_version model_publisher sku_name sku_capacity deployment_state service_tier version_upgrade_option

    deployment_name=$(agent_field "$model" "deploymentName")
    model_name=$(agent_field "$model" "modelName")
    model_format=$(agent_field "$model" "modelFormat")
    model_version=$(agent_field "$model" "modelVersion")
    model_publisher=$(agent_field "$model" "modelPublisher")
    sku_name=$(agent_field "$model" "skuName")
    sku_capacity=$(agent_field "$model" "skuCapacity")
    deployment_state=$(agent_field "$model" "deploymentState")
    service_tier=$(agent_field "$model" "serviceTier")
    version_upgrade_option=$(agent_field "$model" "versionUpgradeOption")

    if az cognitiveservices account deployment show \
      --name "$AIFOUNDRY_ACCOUNT_NAME" \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --deployment-name "$deployment_name" \
      >/dev/null 2>&1; then
      echo "Model deployment ${deployment_name} already exists"
      continue
    fi

    echo "=== Creating model deployment ${deployment_name} (${model_name}) ==="
    az deployment group create \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --template-file azure/infra/model-deployment.bicep \
      --parameters \
        accountName="$AIFOUNDRY_ACCOUNT_NAME" \
        deploymentName="$deployment_name" \
        modelName="$model_name" \
        modelFormat="$model_format" \
        modelVersion="$model_version" \
        modelPublisher="$model_publisher" \
        skuName="$sku_name" \
        skuCapacity="$sku_capacity" \
        deploymentState="$deployment_state" \
        serviceTier="$service_tier" \
        versionUpgradeOption="$version_upgrade_option" \
      --output none
  done < <(jq -c '.[]' <<< "$missing_models")
}

deploy_agent_infra() {
  local agents="${AGENTS:?AGENTS is required}"

  while IFS= read -r agent; do
    local agent_name agent_id agent_version deployment_name

    agent_name=$(agent_field "$agent" "agentName")
    agent_id=$(agent_field "$agent" "agentId")
    agent_version=$(agent_field "$agent" "agentVersion")
    deployment_name=$(agent_field "$agent" "deploymentName")

    echo "=== Deploying application infra for ${agent_name} ==="

    az deployment group create \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --template-file azure/infra/agent-publish.bicep \
      --parameters \
        accountName="$AIFOUNDRY_ACCOUNT_NAME" \
        projectName="$PROJECT_NAME" \
        agentName="$agent_name" \
        agentId="$agent_id" \
        agentVersion="$agent_version" \
        deploymentName="$deployment_name" \
      --output none
  done < <(jq -c '.[]' <<< "$agents")
}
