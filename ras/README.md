# Raspberry Pi Nomad Setup

This directory contains scripts to set up and manage Nomad on a Raspberry Pi. The Raspberry Pi can be configured to run in two different modes:

1. **Client-only mode** - The Raspberry Pi runs as a Nomad client that connects to your local machine's Nomad server.
2. **Server+Client mode** - The Raspberry Pi runs both a Nomad server and client, creating a separate datacenter that joins your main Nomad cluster.

## Prerequisites

- A Raspberry Pi with Debian/Ubuntu-based OS
- Network connectivity between your local machine and the Raspberry Pi
- Nomad binary already installed on the Raspberry Pi
- Docker installed on the Raspberry Pi
- The user `hung` exists on the Raspberry Pi with sudo permissions
- SSH access configured to `ras.local`

## Configuration Files

You can use any Nomad configuration file for your Raspberry Pi. The default paths are:

- **Client-only mode**: `../nomad/config/clients/ras.hcl`
- **Server+Client mode**: `../nomad/config/raspi/nomad.hcl`

You can also create and use custom configuration files as needed.

## Usage

### Setting Up Nomad

You can set up Nomad on the Raspberry Pi with any configuration file:

```bash
# Default (client only)
task setup-nomad

# Server+client mode
task setup-nomad config_file="../nomad/config/raspi/nomad.hcl"

# Custom configuration
task setup-nomad config_file="../nomad/config/custom/my-nomad.hcl"
```

### Updating Configuration

If you've made changes to the configuration files and need to update the Raspberry Pi:

```bash
# Default (client only)
task update-nomad

# Server+client mode
task update-nomad config_file="../nomad/config/raspi/nomad.hcl"

# Custom configuration
task update-nomad config_file="../nomad/config/custom/my-nomad.hcl"
```

### Managing the Nomad Service

```bash
# Stop Nomad
task stop-nomad

# Restart Nomad
task restart-nomad

# View Nomad logs
task logs
```

### Checking Status

```bash
# Check job status
task status

# Check server members (useful for server+client mode)
task check-members
```

### Fixing Common Issues

```bash
# Fix Docker driver issues
task fix-drivers

# Fix cgroup issues
task fix-cgroups
```

### SSH Access

```bash
# SSH into the Raspberry Pi
task ssh
```

## How It Works

The setup script performs the following actions:

1. Creates necessary directories on the Raspberry Pi
2. Sets up Docker credentials
3. Copies the selected configuration file to the Raspberry Pi
4. If using a server configuration (detected by "raspi" in the file path), automatically updates the configuration with the Raspberry Pi's actual IP address
5. Sets up a systemd service to manage Nomad
6. Starts the Nomad service

## Troubleshooting

If you encounter issues:

1. Check the Nomad logs: `task logs`
2. Verify connectivity between your local machine and the Raspberry Pi
3. Ensure the ports required by Nomad (4646, 4647, 4648) are accessible
4. If using server+client mode, verify that both Nomad servers can see each other: `task check-members` 