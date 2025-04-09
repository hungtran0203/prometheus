# Nomad configuration for GCP datacenter

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
  # Specify which datacenter this server belongs to
  datacenter = "gcp"
  
  # Enable server-to-server communication
  server_join {
    retry_join = ["192.168.1.104:4648"]  # Local datacenter server address
    retry_max = 3
    retry_interval = "15s"
  }
}

# Primary datacenter
datacenter = "gcp"

# Client settings
client {
  enabled = true
  # Specify which datacenter this client belongs to
  datacenter = "gcp"
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
  }
}

# Vault integration
vault {
  enabled = true
  address = "http://vault.service.consul:8200"
  token = "root"  # Using the root token for development
  create_from_role = "nomad-cluster"
}

# Consul integration
consul {
  address = "192.168.1.104:8600"  # Point to local Consul server
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
data_dir = "/opt/nomad/data"

# Bind to all interfaces to be accessible from containers
bind_addr = "0.0.0.0"

# Advertise on the GCP instance's IP address
# Note: Replace GCP_INSTANCE_IP with your actual GCP instance's public IP
advertise {
  http = "GCP_INSTANCE_IP"
  rpc  = "GCP_INSTANCE_IP"
  serf = "GCP_INSTANCE_IP"
} 