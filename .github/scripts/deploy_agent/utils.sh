#!/usr/bin/env bash

agent_file_to_name() {
  local agent_file="$1"
  basename "$agent_file" .json
}

agent_field() {
  local agent_json="$1"
  local field_name="$2"
  jq -r --arg field "$field_name" '.[$field]' <<< "$agent_json"
}

log_response() {
  local label="$1"
  local response="$2"
  echo "${label}: ${response}"
}

write_output_json() {
  local output_name="$1"
  local output_value="$2"

  {
    echo "${output_name}<<EOF"
    echo "$output_value"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
}

append_agent() {
  local current_json="$1"
  local agent_json="$2"
  jq -c --argjson item "$agent_json" '. + [$item]' <<< "$current_json"
}

require_json_field() {
  local json_payload="$1"
  local jq_filter="$2"
  local error_message="$3"
  local value

  value=$(jq -r "$jq_filter" <<< "$json_payload")
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "$error_message"
    echo "$json_payload"
    exit 1
  fi

  printf '%s' "$value"
}
