#!/bin/bash

# This script will initialize and set up Vault with some common configuration
# It should be run after Vault has been started, unsealed, and you've logged in with the root token

# Make script executable: chmod +x ./vault/init-vault.sh
# Run: ./vault/init-vault.sh

set -e

echo "Setting up Vault..."

# Set environment variables for local development
export VAULT_ADDR='http://vault.service.consul:8200'
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN='root'

# Enable audit logging to file
docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault audit enable file file_path=/vault/logs/audit.log"

# Check if KV secrets engine is already enabled
KV_ENABLED=$(docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault secrets list | grep 'secret/' || true")

if [ -z "$KV_ENABLED" ]; then
  # Enable the KV secrets engine v2
  docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault secrets enable -path=secret kv-v2"
  echo "✓ KV secrets engine v2 enabled at path 'secret'"
else
  echo "✓ KV secrets engine already enabled at path 'secret'"
fi

# Create example policies
docker exec -it hc-vault sh -c "echo 'path \"secret/data/application/*\" {
  capabilities = [\"create\", \"update\", \"read\", \"delete\", \"list\"]
}

path \"secret/metadata/application/*\" {
  capabilities = [\"list\"]
}' > /tmp/app-policy.hcl"

docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault policy write app-policy /tmp/app-policy.hcl"
echo "✓ Created 'app-policy' policy"

# Copy Nomad policy file into container
docker cp nomad-policy.hcl hc-vault:/tmp/nomad-policy.hcl
echo "✓ Copied nomad-policy.hcl into container"

# Create and configure Nomad policy and role
docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault policy write nomad-policy /tmp/nomad-policy.hcl"
echo "✓ Created 'nomad-policy' policy"

# Create the nomad-cluster role
docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault write auth/token/roles/nomad-cluster \
    period=\"259200s\" \
    orphan=true \
    renewable=true \
    bound_cidrs=\"127.0.0.1/32\" \
    policies=nomad-policy"
echo "✓ Created 'nomad-cluster' role"

# Check if userpass auth is already enabled
USERPASS_ENABLED=$(docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault auth list | grep 'userpass/' || true")

if [ -z "$USERPASS_ENABLED" ]; then
  # Enable userpass authentication method
  docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault auth enable userpass"
  echo "✓ Enabled userpass authentication"
else
  echo "✓ Userpass authentication already enabled"
fi

# Create an example user
echo "Creating example user 'appuser' with password 'password'..."
docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault write auth/userpass/users/appuser \
    password=password \
    policies=app-policy"

# Create some example secrets
echo "Creating example secrets..."
docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault kv put secret/application/database \
    username=db_user \
    password=db_password \
    host=postgres.example.com \
    port=5432"

docker exec -it hc-vault sh -c "VAULT_ADDR='http://vault.service.consul:8200' VAULT_SKIP_VERIFY=true VAULT_TOKEN='root' vault kv put secret/application/api \
    key=api_key_12345 \
    endpoint=https://api.example.com"

echo "Vault setup complete!"
echo "You can access the Vault UI at http://vault.service.consul:8200/ui"
echo "Example credentials:"
echo "  Method: Userpass"
echo "  Username: appuser"
echo "  Password: password" 