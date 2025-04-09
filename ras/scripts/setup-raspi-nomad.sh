#!/bin/bash

# Setup script for Nomad client on Raspberry Pi
# This script configures and starts a Nomad client on a Raspberry Pi device

# Configuration options
RPI_HOST="ras.local"
RPI_USER="hung"
NOMAD_CONFIG_SRC="nomad/config/clients/ras.hcl"
NOMAD_CONFIG_DEST="/etc/nomad.d/nomad.hcl"
NOMAD_DATA_DIR="/home/hung/nomad_data"

# Print script banner
echo "========================================"
echo "Raspberry Pi Nomad Client Setup"
echo "========================================"

# Ensure the Raspberry Pi has the necessary directories
echo "Creating required directories..."
ssh ${RPI_USER}@${RPI_HOST} "sudo mkdir -p /etc/nomad.d ${NOMAD_DATA_DIR} && sudo chown -R ${RPI_USER}:${RPI_USER} ${NOMAD_DATA_DIR}"

# Set up Docker authentication
echo "Setting up Docker credentials..."
ssh ${RPI_USER}@${RPI_HOST} "mkdir -p ~/.docker"

# Check if Docker credentials file exists
if ssh ${RPI_USER}@${RPI_HOST} "[ -f ~/.docker/config.json ]"; then
  echo "Docker credentials file already exists"
else
  echo "Creating empty Docker credentials file"
  ssh ${RPI_USER}@${RPI_HOST} "echo '{}' > ~/.docker/config.json"
  
  # Set proper permissions
  ssh ${RPI_USER}@${RPI_HOST} "chmod 600 ~/.docker/config.json"
fi

# Copy the client configuration
echo "Copying Nomad configuration..."
scp ${NOMAD_CONFIG_SRC} ${RPI_USER}@${RPI_HOST}:/home/${RPI_USER}/ras-client.hcl
ssh ${RPI_USER}@${RPI_HOST} "sudo cp /home/${RPI_USER}/ras-client.hcl ${NOMAD_CONFIG_DEST}"

# Stop any existing Nomad process
echo "Stopping existing Nomad process (if any)..."
ssh ${RPI_USER}@${RPI_HOST} "sudo systemctl stop nomad 2>/dev/null || sudo pkill -f 'nomad agent' || true"

# Start Nomad
echo "Starting Nomad client..."
ssh ${RPI_USER}@${RPI_HOST} "sudo systemctl start nomad 2>/dev/null || sudo nomad agent -config=${NOMAD_CONFIG_DEST} > /home/${RPI_USER}/nomad.log 2>&1 &"

echo "✅ Nomad client configuration deployed to Raspberry Pi (${RPI_HOST})"
echo "Check status with: ssh ${RPI_USER}@${RPI_HOST} 'sudo systemctl status nomad || ps aux | grep nomad'"
echo "To check logs: ssh ${RPI_USER}@${RPI_HOST} 'cat /home/${RPI_USER}/nomad.log'"
echo "Client UI should be available at: http://${RPI_HOST}:4646" 