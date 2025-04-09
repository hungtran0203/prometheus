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

    task "demo" {
      driver = "raw_exec"

      config {
        command = "sh"
        args = [
          "-c",
          "export VAULT_SECRET=$(curl -s -X GET -H \"X-Vault-Token: root\" http://192.168.1.104:8200/v1/secret/data/demo | grep -o '\"message\":\"[^\"]*' | cut -d '\"' -f 4) && echo \"Secret from Vault: $VAULT_SECRET\" && echo \"Success! Waiting...\" && while true; do echo \"Still running...\"; sleep 10; done"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
} 