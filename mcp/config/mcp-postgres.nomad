job "mcp" {
  datacenter = "local"
  type = "service"

  group "mcp" {
    count = 1

    network {
      port "http" {
        static = 8080
        to     = 8080
      }
    }

    service {
      name = "mcp"
      port = "http"
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "mcp" {
      driver = "docker"

      config {
        image = "ghcr.io/hungtran0203/mcp:latest"
        ports = ["http"]
      }

      env {
        POSTGRES_HOST     = "postgres.service.consul"
        POSTGRES_PORT     = "5432"
        POSTGRES_USER     = "mcp"
        POSTGRES_PASSWORD = "mcp123"
        POSTGRES_DB       = "mcp"
        LOG_LEVEL         = "info"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }

  group "postgres" {
    count = 1

    network {
      port "db" {
        static = 5432
        to     = 5432
      }
    }

    service {
      name = "postgres"
      port = "db"
      check {
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:15-alpine"
        ports = ["db"]
      }

      env {
        POSTGRES_USER     = "mcp"
        POSTGRES_PASSWORD = "mcp123"
        POSTGRES_DB       = "mcp"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      volume_mount {
        volume      = "postgres-data"
        destination = "/var/lib/postgresql/data"
      }
    }
  }
} 