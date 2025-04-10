# Nomad configuration for local development

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
}

datacenter = "dc1"

# Client settings
client {
  enabled = true
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
  }

  # Join the Docker network
  network_interface = "docker0"
}

# Vault integration
vault {
  enabled = true
  address = "http://172.28.0.2:8200"  # Vault's static IP in the private network
  token = "root"  # Using the root token for development
  create_from_role = "nomad-cluster"
}

# Consul integration
consul {
  address = "172.28.0.3:8500"  # Consul's static IP in the private network
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
  http = "127.0.0.1"
  rpc  = "127.0.0.1"
  serf = "127.0.0.1"
}

# Configure network for container networking
client {
  cni_path = "/opt/cni/bin"
  cni_config_dir = "/etc/cni/net.d"

  # Enable bridge network mode for better container-to-container communication
  host_network = false

  # Tell Nomad which docker network to use
  host_network_interface = "docker0"
} 