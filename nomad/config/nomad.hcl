# Nomad configuration with Vault and Consul integration

# Server settings
server {
  enabled = true
  bootstrap_expect = 1
  
  # Enable server's Vault integration
  vault {
    enabled = true
    address = "http://vault:8200"
    create_from_role = "nomad-cluster"
    token = ""  # Will be supplied via environment variable
  }
}

# Client settings
client {
  enabled = true
  
  # Configure client to expose metrics for Prometheus
  meta {
    "prometheus.metrics.enabled" = "true"
  }
}

# Consul integration
consul {
  address = "consul:8500"
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
  
  # Enable Consul telemetry integration
  disable_hostname = true
  prometheus_retention_time = "24h"
}

# Bind to all interfaces to be accessible from host
addresses {
  http = "0.0.0.0"
  rpc  = "0.0.0.0"
  serf = "0.0.0.0"
}

# Advertise on the container IP address
advertise {
  http = "{{ GetInterfaceIP \"eth0\" }}"
  rpc  = "{{ GetInterfaceIP \"eth0\" }}"
  serf = "{{ GetInterfaceIP \"eth0\" }}"
} 