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
}

data_dir = "/home/hung/nomad_data"

plugin "docker" {
  config {
    # Docker configuration
    extra_labels = ["job_name", "task_group", "task_name", "namespace", "node_name"]
  }
}

# Enable Consul and set the address to the host machine
consul {
  enabled = true
  address = "192.168.1.104:8600"
}

# Enable Vault integration
vault {
  enabled = true
  address = "http://192.168.1.104:8200"
  token = "root"  # Using the root token for development
  create_from_role = "nomad-cluster"
}
