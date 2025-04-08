client {
  enabled = true
  servers = ["192.168.1.104:4647"]
  disable_remote_exec = true
  options = {
    "driver.raw_exec.enable" = "1"
    "driver.exec.enable" = "0"
    "driver.java.enable" = "0"
    "docker.auth.config"     = "/home/hung/.docker/config.json"
  }
}

data_dir = "/home/hung/nomad_data"

plugin "docker" {
  config {
    volumes {
      enabled      = true
      selinuxlabel = false
    }
  }
}

consul {
  enabled = false
}
