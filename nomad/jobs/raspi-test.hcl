job "raspi-test" {
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
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sh"
        args = [
          "-c",
          "echo 'Hello from Raspberry Pi!'; node -e 'console.log(\"Running on Raspberry Pi\"); setInterval(() => console.log(\"Still running...\"), 10000);'"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
} 