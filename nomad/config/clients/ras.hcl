client {
  enabled = true
  servers = ["192.168.1.104:4647"]
  disable_remote_exec = true
  node_class = "ras"
  options = {
    "driver.raw_exec.enable" = "1"
    "driver.exec.enable" = "1"
    "driver.java.enable" = "1"
    "driver.exec.no_cgroups" = "1"
    "driver.java.no_cgroups" = "1"
  }
  
  # Network configuration for the client
  network_interface = "wlan0"  # Use WiFi interface to connect to server
}

data_dir = "/home/hung/nomad_data"

plugin "docker" {
  config {
    # Docker configuration
    extra_labels = ["job_name", "task_group", "task_name", "namespace", "node_name"]
    
    # Connect to the nomad_network
    network_mode = "nomad_network"
    
    # Allow jobs to specify bridge networking mode
    allow_privileged = true
    
    # Allow jobs to use pre-defined Docker networks
    allow_caps = ["NET_ADMIN", "SYS_ADMIN"]
    
    # Configure Docker network settings
    volumes {
      enabled = true
    }
  }
}

# Enable Consul and set the address to the host machine
consul {
  enabled = true
  address = "192.168.1.104:8500"  # Updated to use HTTP API port instead of DNS
}

# Enable Vault integration
vault {
  enabled = true
  address = "http://192.168.1.104:8200"
  token = "root"  # Using the root token for development
  create_from_role = "nomad-cluster"
}

# Configure CNI for network plugin support
client {
  cni_path = "/opt/cni/bin"
  cni_config_dir = "/etc/cni/net.d"
  
  # Network settings for connecting to nomad_network
  bridge_network_name = "nomad_network"
  bridge_network_subnet = "172.28.0.0/16"
}
