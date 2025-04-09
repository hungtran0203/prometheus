#!/bin/bash

# Script to register services from JSON files in the consul/services directory

CONSUL_API=${CONSUL_API:-"http://localhost:8500"}
SERVICE_DIR="./consul/services"

echo "Registering Consul services from ${SERVICE_DIR}..."

for service_file in "${SERVICE_DIR}"/*.json; do
  if [ -f "$service_file" ]; then
    service_name=$(basename "$service_file" .json)
    echo "Registering $service_name from $(basename "$service_file")..."
    
    # Create a temporary file with proper format for Consul API
    # The API expects just the service definition without a Service wrapper
    cat "$service_file" > /tmp/service-payload.json
    
    # Create a PUT request to register the service
    if curl -s -X PUT -d @"/tmp/service-payload.json" "${CONSUL_API}/v1/agent/service/register"; then
      echo "✅ Successfully registered $service_name"
    else
      echo "❌ Failed to register $service_name"
    fi
  fi
done

rm -f /tmp/service-payload.json
echo "Service registration complete!" 