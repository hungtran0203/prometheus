job "vault-example" {
  datacenters = ["dc1"]
  type        = "service"
  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ras"
  }

  group "app" {
    count = 1

    # Specify Vault policies needed for this group
    vault {
      policies = ["nomad-server"]
      change_mode = "restart"
    }

    task "demo" {
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sh"
        args = [
          "-c",
          "echo \"Secret from Vault: $${VAULT_SECRET}\"; node -e 'console.log(\"Node.js with Vault secret: \" + process.env.VAULT_SECRET); setInterval(() => console.log(\"Still running...\"), 10000);'"
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