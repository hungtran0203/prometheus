job "local-test" {
  datacenters = ["dc1"]
  type        = "batch"

  group "app" {
    count = 1

    task "demo" {
      driver = "raw_exec"

      config {
        command = "sh"
        args = [
          "-c",
          "echo 'Testing local job execution' > /tmp/local-test.txt && echo 'Success!' && hostname"
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
} 