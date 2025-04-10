job "docker-node" {
  datacenters = ["dc1", "aws", "gcp"]
  type        = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        static = 8080
      }
      
      # Connect to the Nomad network
      mode = "bridge"
    }

    service {
      name = "node-2"
      port = "http"
      
      tags = [
        "app",
        "node",
        "traefik.enable=true",
        "traefik.http.routers.node.rule=Host(`node.localhost`)"
      ]
      
      # Use consul on the private network
      address_mode = "driver"
    }

    task "node" {
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sh"
        args = ["-c", "echo 'Starting Node.js server on port 8080' && npm install -g http-server && http-server -p 8080"]
        ports = ["http"]
        
        # Connect to the Nomad network
        network_mode = "nomad_network"
      }

      resources {
        cpu    = 100
        memory = 256
      }
      
      env {
        CONSUL_HTTP_ADDR = "http://172.28.0.3:8500"
      }
    }
  }
} 