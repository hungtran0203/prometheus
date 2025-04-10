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
    retry_join = ["nomad.service.consul:4648"]
    retry_max = 5
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
  address = "vault.service.consul:8200"  # Use Consul DNS
  token = "root"  # Using the root token for development
}

# Consul integration - use existing Consul from hashicorp-stack
consul {
  address = "consul.service.consul:8500"  # Use existing Consul server on macOS
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
  
  # Service registration settings
  server_service_name = "nomad-raspi"
  client_service_name = "nomad-raspi-client"
}

# UI settings
ui {
  enabled = true
}

# Enable metrics collection
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

# Data directory - adjust this path based on your Raspberry Pi setup
data_dir = "/opt/nomad/data"

# Bind to all interfaces to be accessible from other nodes
bind_addr = "0.0.0.0"

# Advertise using DNS-resolvable name from Consul
advertise {
  # Replace this with the hostname or DNS name once registered in Consul
  http = "nomad-raspi.service.consul"
  rpc  = "nomad-raspi.service.consul"
  serf = "nomad-raspi.service.consul"
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

# Plugin directory
plugin_dir = "/opt/nomad/plugins"

# Name of the node
name = "ras"

# Enable raw_exec driver for running scripts
plugin "raw_exec" {
  config {
    enabled = true
  }
}

# Set up logging
log_level = "INFO"
log_file = "/var/log/nomad/nomad.log" 