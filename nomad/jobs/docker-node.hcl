job "docker-node" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {
    count = 1

    task "node" {
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sleep"
        args = ["infinity"]
        interactive = true
        tty = true
        privileged = false
        volumes = []
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
} 