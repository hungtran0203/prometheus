# Nomad configuration for AWS datacenter

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
  # Specify which datacenter this server belongs to
  datacenter = "aws"
}

# Primary datacenter
datacenter = "aws"

# Client settings
client {
  enabled = true
  # Specify which datacenter this client belongs to
  datacenter = "aws"
  
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
  address = "consul.service.consul:8600"  # Standard Consul DNS port
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

# Advertise on the AWS instance's IP address
# Note: Replace with your actual AWS instance IP
advertise {
  http = "AWS_INSTANCE_IP"
  rpc  = "AWS_INSTANCE_IP"
  serf = "AWS_INSTANCE_IP"
} 