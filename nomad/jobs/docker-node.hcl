job "docker-node" {
  datacenters = ["dc1", "aws", "gcp"]
  type        = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "docker-node"
      port = "http"
      
      tags = [
        "app",
        "node",
        "traefik.enable=true",
        "traefik.http.routers.node.rule=Host(`node.localhost`)"
      ]

      check {
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }

      # Register service with Consul
      connect {
        sidecar_service {}
      }
    }

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
        ports = ["http"]
      }

      env {
        CONSUL_HTTP_ADDR = "http://192.168.1.104:8500"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
} 