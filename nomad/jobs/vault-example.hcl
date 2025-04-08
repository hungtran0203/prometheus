job "vault-example" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {
    count = 1

    # Specify Vault policies needed for this group
    vault {
      policies = ["nomad-server"]
      change_mode = "restart"
    }

    task "demo" {
      driver = "raw_exec"

      config {
        command = "/bin/sh"
        args = [
          "-c",
          "echo \"Secret from Vault: $${VAULT_SECRET}\"; sleep 3600"
        ]
      }

      # Get secrets from Vault
      template {
        data = <<EOH
{{ with secret "secret/data/demo" }}
VAULT_SECRET="{{ .Data.data.message }}"
{{ end }}
EOH
        destination = "local/file.env"
        env = true
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
} 