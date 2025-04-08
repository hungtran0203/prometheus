client {
  enabled = true
  servers = ["http://hung.service.consul:4647"]
  options = {
    "driver.raw_exec.enable" = "1"
    "docker.auth.config"     = "/home/pi/.docker/config.json"
  }
}

plugin "docker" {
  config {
    volumes {
      enabled      = true
      selinuxlabel = false
    }
  }
}
