#!/usr/bin/env bash

put_json() {
  local url="$1"
  local token="$2"
  local body="$3"

  curl --fail-with-body --silent --show-error \
    -X PUT \
    "$url" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

post_json() {
  local url="$1"
  local token="$2"
  local body="$3"

  curl --fail-with-body --silent --show-error \
    -X POST \
    "$url" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

get_json_with_status() {
  local url="$1"
  local token="$2"

  curl --silent --show-error \
    -w "%{http_code}" \
    -H "Authorization: Bearer ${token}" \
    "$url" || true
}
