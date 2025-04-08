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
      driver = "docker"

      config {
        image = "busybox:latest"
        command = "/bin/sh"
        args = [
          "-c",
          "echo \"Secret from Vault: $${VAULT_SECRET}\"; while true; do sleep 30; done"
        ]
      }

      # Get secrets from Vault
      template {
        data = <<EOH
{{ with secret "secret/data/demo" }}
VAULT_SECRET="{{ .Data.data.message }}"
{{ end }}
EOH
        destination = "secrets/file.env"
        env = true
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "vault-demo"
        port = "http"
        tags = ["demo", "vault"]

        check {
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    network {
      port "http" {
        to = 8080
      }
    }
  }
} 