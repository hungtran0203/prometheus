#!/bin/bash

# This script will initialize and set up Vault with some common configuration
# It should be run after Vault has been started, unsealed, and you've logged in with the root token

# Make script executable: chmod +x ./vault/init-vault.sh
# Run: ./vault/init-vault.sh

set -e

echo "Setting up Vault..."

# Enable audit logging to file
docker exec -it vault vault audit enable file file_path=/vault/logs/audit.log

# Enable the KV secrets engine v2
docker exec -it vault vault secrets enable -path=secret kv-v2
echo "✓ KV secrets engine v2 enabled at path 'secret'"

# Create example policies
docker exec -it vault sh -c "echo 'path \"secret/data/application/*\" {
  capabilities = [\"create\", \"update\", \"read\", \"delete\", \"list\"]
}

path \"secret/metadata/application/*\" {
  capabilities = [\"list\"]
}' > /tmp/app-policy.hcl"

docker exec -it vault vault policy write app-policy /tmp/app-policy.hcl
echo "✓ Created 'app-policy' policy"

# Enable userpass authentication method
docker exec -it vault vault auth enable userpass
echo "✓ Enabled userpass authentication"

# Create an example user
echo "Creating example user 'appuser' with password 'password'..."
docker exec -it vault vault write auth/userpass/users/appuser \
    password=password \
    policies=app-policy

# Create some example secrets
echo "Creating example secrets..."
docker exec -it vault vault kv put secret/application/database \
    username=db_user \
    password=db_password \
    host=postgres.example.com \
    port=5432

docker exec -it vault vault kv put secret/application/api \
    key=api_key_12345 \
    endpoint=https://api.example.com

echo "Vault setup complete!"
echo "You can access the Vault UI at http://localhost:8200/ui"
echo "Example credentials:"
echo "  Method: Userpass"
echo "  Username: appuser"
echo "  Password: password" 