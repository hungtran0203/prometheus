job "docker-node" {
  datacenters = ["dc1", "aws", "gcp"]
  type        = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        static = 8080
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
    }

    task "node" {
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sh"
        args = ["-c", "echo 'Starting Node.js server on port 8080' && npm install -g http-server && http-server -p 8080"]
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
} 