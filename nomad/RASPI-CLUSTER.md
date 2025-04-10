# Setting Up a Multi-Datacenter Nomad Cluster with Raspberry Pi

This guide explains how to set up a Nomad cluster spanning your macOS host and a Raspberry Pi, with each device running in its own datacenter but part of the same cluster.

## Architecture

- **macOS Host**: Runs a Nomad server in datacenter "dc1" along with Consul and Vault services in Docker
- **Raspberry Pi**: Runs a Nomad server and client in datacenter "raspi"
- Both servers are in the same region "global" to enable cluster membership
- The Raspberry Pi Nomad server integrates with the existing Consul and Vault services in the HashiCorp stack

## Prerequisites

1. macOS host with Nomad, Consul, and Vault running in Docker (hashicorp-stack)
2. Raspberry Pi with network connectivity to the macOS host
3. Docker installed on the Raspberry Pi
4. The following ports must be accessible from Raspberry Pi to macOS:
   - Nomad: 4646, 4647, 4648
   - Consul: 8500, 8600
   - Vault: 8200

## Setup Steps

### 1. Set Up the macOS Nomad Server

First, make sure your macOS HashiCorp stack is running with Nomad, Consul, and Vault:

```bash
# From the project directory
cd nomad
task stop
task start
```

Verify the services are running:
```bash
docker ps | grep -E "consul|vault|nomad"
```

### 2. Install Nomad on the Raspberry Pi

```bash
# Replace with your Pi's username and IP
task install-nomad-raspi pi_user=pi pi_ip=192.168.1.105
```

### 3. Deploy Configuration to Raspberry Pi

```bash
# Replace with your Pi's username and IP
task deploy-raspi-config pi_user=pi pi_ip=192.168.1.105
```

This deploys the server+client configuration and systemd service file.

### 4. Start Nomad on the Raspberry Pi

Start Nomad using systemd:

```bash
task start-raspi-service pi_user=pi pi_ip=192.168.1.105
```

Or manually on the Raspberry Pi:

```bash
sudo nomad agent -config=/opt/nomad/config/raspi/nomad.hcl -bind=0.0.0.0
```

### 5. Verify Cluster Formation

```bash
task check-raspi-cluster pi_user=pi pi_ip=192.168.1.105
```

## Running Jobs Across Datacenters

### Job for macOS Only

```hcl
job "macos-job" {
  datacenters = ["dc1"]
  // rest of job spec
}
```

### Job for Raspberry Pi Only

```hcl
job "raspi-job" {
  datacenters = ["raspi"]
  // rest of job spec
}
```

### Job for Both Datacenters

```hcl
job "multi-dc-job" {
  datacenters = ["dc1", "raspi"]
  // rest of job spec
}
```

## Deploying a Job to Raspberry Pi

```bash
# From the macOS host
nomad job run -address=http://RASPI_IP:4646 jobs/raspi-node.hcl

# Or using the task
task job-run-datacenter job_file=./jobs/raspi-node.hcl server_addr=http://RASPI_IP:4646
```

## Command-Line Operation

If you prefer to run Nomad manually via the command line instead of systemd:

```bash
# On the Raspberry Pi
nomad agent -config=/opt/nomad/config/raspi/nomad.hcl -bind=0.0.0.0 -log-level=INFO
```

## Troubleshooting

1. **Cannot see both servers in members list**:
   - Check network connectivity between machines
   - Verify the IP addresses in configuration files are correct
   - Check the Nomad logs: `sudo journalctl -u nomad-server.service -f`

2. **Raspberry Pi cannot join the cluster**:
   - Verify the `retry_join` address points to the correct macOS IP
   - Check firewall settings on both machines to allow ports 4646-4648

3. **Cannot connect to Consul or Vault services**:
   - Ensure Docker containers for these services are running on the macOS host
   - Check the IP address used for connections (should be the macOS IP)
   - Verify the ports are accessible (8500 for Consul, 8200 for Vault)

4. **Jobs don't run on Raspberry Pi**:
   - Verify Docker is installed and running on the Pi
   - Check that the job is targeting the "raspi" datacenter
   - Check driver compatibility (use ARM images for Docker jobs)

## Ports Required

- **Nomad HTTP API**: 4646 (used for the UI and API calls)
- **Nomad RPC**: 4647 (used for client-to-server communication)
- **Nomad Serf**: 4648 (used for server-to-server communication)
- **Consul HTTP API**: 8500 (used for service discovery and registration)
- **Consul DNS**: 8600 (used for DNS service discovery)
- **Vault HTTP API**: 8200 (used for secrets management)

Make sure these ports are allowed through any firewalls between the machines. 