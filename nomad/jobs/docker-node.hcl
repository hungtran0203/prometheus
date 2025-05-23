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
        name     = "alive"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "node" {
      driver = "docker"

      config {
        image = "node:alpine"
        command = "sh"
        args = ["-c", "echo 'Starting Node.js server on port 8080' && npm install -g http-server && echo 'TESTING VAULT CONNECTIVITY:' && echo '- DNS Resolution:' && getent hosts vault.service.consul || echo 'Failed to resolve vault.service.consul' && echo '- HTTP Connection:' && wget -q -T 2 --spider http://vault.service.consul:8200/v1/sys/health && echo 'Vault is reachable over HTTP' || echo 'Vault is NOT reachable over HTTP' && echo '- Starting HTTP Server...' && http-server -p 8080"]
        ports = ["http"]
        
        # Use bridge networking
        network_mode = "bridge"
      }

      env {
        # Use Consul service discovery for addresses
        CONSUL_HTTP_ADDR = "${NOMAD_IP_http}:8500"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
} 