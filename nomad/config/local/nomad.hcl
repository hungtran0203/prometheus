# Nomad configuration for local development

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
  
  # Enable federation with other datacenters 
  enabled_schedulers = ["service", "batch", "system"]
  
  # Allow servers from different datacenters to join
  server_join {
    retry_join = ["nomad-raspi.service.consul:4648"]  # Use DNS for Raspberry Pi Nomad server
    retry_max = 0    # Retry indefinitely 
    retry_interval = "15s"
  }
}

# Explicitly set region for federation
region = "global"

datacenter = "dc1"

# Client settings
client {
  enabled = true
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
  }
  
  # Network configuration
  network_interface = "en0"

  # Docker configuration for networking
  options {
    "docker.bridge.name" = "nomad_bridge"
    "docker.privileged.enabled" = "true"
    "docker.volumes.enabled" = "true"
  }
}

# Vault integration
vault {
  enabled = true
  # Use Consul DNS instead of static IP
  address = "http://vault.service.consul:8200"
  token = "root"
  create_from_role = "nomad-cluster"
}

# Consul integration
consul {
  # Use localhost for local Consul agent
  address = "127.0.0.1:8500"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  server_service_name = "nomad-server"
  client_service_name = "nomad-client"
  
  # Register services with tags for each network
  tags = ["wifi", "nomad_network", "monitoring_network"]
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

# Bind to all interfaces to be accessible from Raspberry Pi
bind_addr = "0.0.0.0"

# Advertise using DNS-resolvable name
advertise {
  http = "nomad.service.consul"
  rpc  = "nomad.service.consul"
  serf = "nomad.service.consul"
} 