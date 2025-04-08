# Nomad configuration for local development

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
}

# Client settings
client {
  enabled = true
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
  }
}

# Vault integration
vault {
  enabled = true
  address = "http://localhost:8200"
  token = "root"  # Using the root token for development
  create_from_role = "nomad-cluster"
}

# Consul integration
consul {
  address = "localhost:8600"  # The exposed port for Consul in the container
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  
  # Service registration settings
  server_service_name = "nomad-server"
  client_service_name = "nomad-client"
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

# Data directory
data_dir = "/Volumes/Data/working/hungtran0203/prometheus/nomad/data"

# Bind to all interfaces to be accessible from containers
bind_addr = "0.0.0.0"

# Advertise on the host's IP address
advertise {
  http = "localhost"
  rpc  = "localhost"
  serf = "localhost"
} 