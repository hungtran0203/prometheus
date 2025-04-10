#!/bin/bash

# Setup script for Nomad on Raspberry Pi
# This script configures and starts a Nomad instance on a Raspberry Pi device
# Can use any configuration file specified by NOMAD_CONFIG_FILE

# Configuration options
RPI_HOST="ras.local"
RPI_USER="hung"
NOMAD_DATA_DIR="/home/hung/nomad_data"
NOMAD_CONFIG_DEST="/etc/nomad.d/nomad.hcl"

# Get the configuration file from environment variable
# Default to client config if not specified
NOMAD_CONFIG_FILE="${NOMAD_CONFIG_FILE:-../nomad/config/clients/ras.hcl}"

# Get the configuration file name for better messaging
CONFIG_NAME=$(basename ${NOMAD_CONFIG_FILE})

# Print script banner
echo "========================================"
echo "Using configuration: ${CONFIG_NAME}"
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

# Copy the configuration
echo "Copying Nomad configuration from ${NOMAD_CONFIG_FILE}..."
scp ${NOMAD_CONFIG_FILE} ${RPI_USER}@${RPI_HOST}:/home/${RPI_USER}/nomad-config.hcl

# If this is a server+client config, need to update the advertise block with actual IP
echo "Updating advertise IPs in server configuration..."
RASPI_IP=$(ssh ${RPI_USER}@${RPI_HOST} "hostname -I | awk '{print \$1}'")
ssh ${RPI_USER}@${RPI_HOST} "sed -i 's/RASPI_IP/${RASPI_IP}/g' /home/${RPI_USER}/nomad-config.hcl"
echo "Set Raspberry Pi IP to: ${RASPI_IP}"
# Copy to system location
ssh ${RPI_USER}@${RPI_HOST} "sudo cp /home/${RPI_USER}/nomad-config.hcl ${NOMAD_CONFIG_DEST}"

# Create systemd service if it doesn't exist
echo "Setting up systemd service..."
ssh ${RPI_USER}@${RPI_HOST} "cat > /tmp/nomad.service << EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF"

ssh ${RPI_USER}@${RPI_HOST} "sudo mv /tmp/nomad.service /etc/systemd/system/nomad.service && sudo systemctl daemon-reload"

# Stop any existing Nomad process
echo "Stopping existing Nomad process (if any)..."
ssh ${RPI_USER}@${RPI_HOST} "sudo systemctl stop nomad 2>/dev/null || sudo pkill -f 'nomad agent' || true"

# Start Nomad
echo "Starting Nomad with ${CONFIG_NAME}..."
ssh ${RPI_USER}@${RPI_HOST} "sudo systemctl start nomad"

echo "✅ Nomad configuration deployed to Raspberry Pi (${RPI_HOST})"
echo "Check status with: ssh ${RPI_USER}@${RPI_HOST} 'sudo systemctl status nomad'"
echo "UI should be available at: http://${RPI_HOST}:4646" 