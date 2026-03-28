#!/usr/bin/env bash

build_agent_create_body() {
  local agent_name="$1"
  local agent_file="$2"

  jq -n \
    --arg name "$agent_name" \
    --slurpfile def "$agent_file" \
    '{
      name: $name,
      definition: $def[0]
    }'
}

build_agent_update_body() {
  local agent_file="$1"

  jq -n \
    --slurpfile def "$agent_file" \
    '{
      definition: $def[0]
    }'
}

build_application_body() {
  local agent_name="$1"
  local agent_id="$2"

  jq -n \
    --arg displayName "$agent_name" \
    --arg description "Published agent application for ${agent_name}" \
    --arg agentId "$agent_id" \
    --arg agentName "$agent_name" \
    '{
      properties: {
        agents: [
          {
            agentId: $agentId,
            agentName: $agentName
          }
        ],
        displayName: $displayName,
        description: $description
      }
    }'
}

build_deployment_body() {
  local agent_name="$1"
  local agent_version="$2"

  jq -n \
    --arg agentName "$agent_name" \
    --arg agentVersion "$agent_version" \
    --arg displayName "${agent_name} deployment" \
    '{
      properties: {
        agents: [
          {
            agentName: $agentName,
            agentVersion: $agentVersion
          }
        ],
        deploymentType: "Managed",
        displayName: $displayName,
        protocols: [
          {
            protocol: "Responses",
            version: "1.0"
          }
        ],
        state: "Starting"
      }
    }'
}

build_application_link_body() {
  local agent_name="$1"
  local agent_id="$2"
  local deployment_id="$3"

  jq -n \
    --arg displayName "$agent_name" \
    --arg description "Published agent application for ${agent_name}" \
    --arg agentId "$agent_id" \
    --arg agentName "$agent_name" \
    --arg deploymentId "$deployment_id" \
    '{
      properties: {
        agents: [
          {
            agentId: $agentId,
            agentName: $agentName
          }
        ],
        displayName: $displayName,
        description: $description,
        authorizationPolicy: {
          authorizationScheme: "Default"
        },
        trafficRoutingPolicy: {
          protocol: "FixedRatio",
          rules: [
            {
              ruleId: "default",
              description: "Default rule routing all traffic to the first deployment",
              deploymentId: $deploymentId,
              trafficPercentage: 100
            }
          ]
        }
      }
    }'
}

build_agent_state() {
  local agent_name="$1"
  local agent_file="$2"
  local agent_id="$3"
  local agent_version="$4"
  local app_name="$5"
  local deployment_name="$6"
  local model_deployment_name="$7"
  local model_name="$8"
  local model_format="$9"
  local model_version="$10"
  local model_publisher="${11}"
  local sku_name="${12}"
  local sku_capacity="${13}"
  local deployment_state="${14}"
  local service_tier="${15}"
  local version_upgrade_option="${16}"

  echo "==== build_agent_state ==== model_version: ${model_version}"

  jq -c -n \
    --arg agentName "$agent_name" \
    --arg agentFile "$agent_file" \
    --arg agentId "$agent_id" \
    --arg agentVersion "$agent_version" \
    --arg appName "$app_name" \
    --arg deploymentName "$deployment_name" \
    --arg modelDeploymentName "$model_deployment_name" \
    --arg modelName "$model_name" \
    --arg modelFormat "$model_format" \
    --arg modelVersion "$model_version" \
    --arg modelPublisher "$model_publisher" \
    --arg skuName "$sku_name" \
    --arg deploymentState "$deployment_state" \
    --arg serviceTier "$service_tier" \
    --arg versionUpgradeOption "$version_upgrade_option" \
    --argjson skuCapacity "$sku_capacity" \
    '{
      agentName: $agentName,
      agentFile: $agentFile,
      agentId: $agentId,
      agentVersion: $agentVersion,
      appName: $appName,
      deploymentName: $deploymentName,
      modelDeploymentName: $modelDeploymentName,
      modelName: $modelName,
      modelFormat: $modelFormat,
      modelVersion: $modelVersion,
      modelPublisher: $modelPublisher,
      skuName: $skuName,
      skuCapacity: $skuCapacity,
      deploymentState: $deploymentState,
      serviceTier: $serviceTier,
      versionUpgradeOption: $versionUpgradeOption
    }'
}
