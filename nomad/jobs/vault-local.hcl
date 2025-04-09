job "vault-local" {
  datacenters = ["dc1"]
  type        = "batch"

  constraint {
    attribute = "${node.unique.hostname}"
    operator  = "="
    value     = "MacBook-Pro.local"
  }

  group "app" {
    count = 1

    task "demo" {
      driver = "raw_exec"

      config {
        command = "sh"
        args = [
          "-c",
          "curl -s -X GET -H \"X-Vault-Token: root\" http://localhost:8200/v1/secret/data/demo | jq -r '.data.data.message' | tee /tmp/vault-secret-local.txt && echo \"Success! Secret saved to /tmp/vault-secret-local.txt\""
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
} 