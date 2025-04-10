# Nomad configuration for Raspberry Pi - server and client mode
# This allows the Raspberry Pi to run in its own datacenter but connect to the local machine

# Specify the datacenter
datacenter = "raspi"

# Use the same region as the macOS server
region = "global"

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
  
  # Join the existing datacenter servers on local machine
  server_join {
    retry_join = ["192.168.1.104:4648"]  # Local datacenter server address
    retry_max = 3
    retry_interval = "15s"
  }
}

# Client settings
client {
  enabled = true
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
    "node_type" = "raspberry_pi"
  }
}

# Vault integration - use existing Vault from hashicorp-stack
vault {
  enabled = true
  address = "http://192.168.1.104:8200"  # Direct access to existing Vault
  token = "root"  # Using the root token for development
}

# Consul integration - use existing Consul from hashicorp-stack
consul {
  address = "192.168.1.104:8500"  # Use existing Consul server on macOS
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  
  # Service registration settings
  server_service_name = "nomad-server-raspi"
  client_service_name = "nomad-client-raspi"
}

# UI settings
ui {
  enabled = true
}

# Enable metrics collection
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics = true
  prometheus_metrics = true
  disable_hostname = true
}

# Data directory - adjust this path based on your Raspberry Pi setup
data_dir = "/opt/nomad/data"

# Bind to all interfaces to be accessible from other nodes
bind_addr = "0.0.0.0"

# Advertise on the Raspberry Pi's IP address
# Replace RASPI_IP with your actual Raspberry Pi's IP address
advertise {
  http = "RASPI_IP"
  rpc  = "RASPI_IP"
  serf = "RASPI_IP"
}

# Docker configuration for networking
plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
} 