# Proxy App Monitoring - Task Runner
# Run commands with: just <command>

# Default recipe to display help information
default:
    @just --list

# Docker Commands
# These commands are now in docker/Justfile
# Usage: just -f docker/Justfile <command>
# Examples:
#   just -f docker/Justfile start
#   just -f docker/Justfile stop
#   just -f docker/Justfile restart
#   just -f docker/Justfile status
#   just -f docker/Justfile logs nginx
#   just -f docker/Justfile open grafana
#   just -f docker/Justfile show-targets
#   just -f docker/Justfile add-app myapp 3000 33000
#   just -f docker/Justfile remove-app myapp 3000
#   just -f docker/Justfile list-apps

# Monitoring Commands
# These commands are now in prometheus/Justfile
# Usage: just -f prometheus/Justfile <command>
# Examples:
#   just -f prometheus/Justfile forward-logs 3000
#   just -f prometheus/Justfile get-log 83976
#   just -f prometheus/Justfile docker-logs
#   just -f prometheus/Justfile docker-logs-detailed

# Nomad Commands
# These commands are now in nomad/Justfile
# Usage: just -f nomad/Justfile <command>
# Examples:
#   just -f nomad/Justfile start
#   just -f nomad/Justfile stop
#   just -f nomad/Justfile run ./jobs/vault-example.hcl
#   just -f nomad/Justfile stop-job vault-example
#   just -f nomad/Justfile status
#   just -f nomad/Justfile setup-raspi
#   just -f nomad/Justfile fix-raspi-drivers
#   just -f nomad/Justfile fix-raspi-cgroups
#   just -f nomad/Justfile ssh-raspi

# DNS Configuration Commands
# These commands are now in dnsmasq/Justfile
# Usage: just -f dnsmasq/Justfile <command>
# Examples:
#   just -f dnsmasq/Justfile start
#   just -f dnsmasq/Justfile stop
#   just -f dnsmasq/Justfile restart
#   just -f dnsmasq/Justfile status
#   just -f dnsmasq/Justfile test
#   just -f dnsmasq/Justfile test-consul
#   just -f dnsmasq/Justfile test-external

# -------------------- Consul Commands --------------------

# Run a command in the Consul Justfile
# Usage: just consul COMMAND [ARGS...]
# Example: just consul register-services
consul *ARGS:
    #!/usr/bin/env bash
    cd consul && just {{ARGS}}

