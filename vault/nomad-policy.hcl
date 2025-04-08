# Allow creating tokens under "nomad-cluster" role
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

# Allow looking up "nomad-cluster" role
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

# Allow looking up the token passed to Nomad to validate the token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow looking up incoming tokens to validate
path "auth/token/lookup" {
  capabilities = ["update"]
}

# Allow revoking tokens
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

# Allow checking token capabilities
path "sys/capabilities-self" {
  capabilities = ["update"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow access to the kv store
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
} 