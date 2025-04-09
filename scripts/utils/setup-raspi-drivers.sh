#!/bin/bash

# Fix Java and Exec drivers on Raspberry Pi Nomad client
# This script installs necessary dependencies and configures the system

# Configuration options
RPI_HOST="ras.local"
RPI_USER="hung"

# Print script banner
echo "========================================"
echo "Fixing Exec and Java drivers on Raspberry Pi"
echo "========================================"

# Copy the updated config to the Raspberry Pi
echo "Copying updated Nomad configuration..."
scp nomad/config/clients/ras.hcl ${RPI_USER}@${RPI_HOST}:/home/${RPI_USER}/ras-client.hcl
ssh ${RPI_USER}@${RPI_HOST} "sudo cp /home/${RPI_USER}/ras-client.hcl /etc/nomad.d/nomad.hcl"

# Check if Java is installed
echo "Checking for Java dependencies..."
if ssh ${RPI_USER}@${RPI_HOST} "which java"; then
  echo "Java is already installed"
else
  echo "Installing OpenJDK..."
  ssh ${RPI_USER}@${RPI_HOST} "sudo apt-get update && sudo apt-get install -y openjdk-11-jre-headless"
fi

# Check if we need to create Java symlinks
echo "Setting up Java environment..."
ssh ${RPI_USER}@${RPI_HOST} "if [ ! -d /usr/lib/jvm/default-java ]; then sudo mkdir -p /usr/lib/jvm && sudo ln -sf \$(readlink -f /usr/bin/java | sed 's|/bin/java||') /usr/lib/jvm/default-java; fi"

# Check if we need to create the systemd service that mounts the cgroup hierarchy
echo "Setting up cgroup mount service..."
cat > /tmp/cgroup-mount.service << EOF
[Unit]
Description=Mount cgroups for Nomad
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "mkdir -p /sys/fs/cgroup/systemd && mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd"
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Copy the systemd service file to the Raspberry Pi
scp /tmp/cgroup-mount.service ${RPI_USER}@${RPI_HOST}:/tmp/
ssh ${RPI_USER}@${RPI_HOST} "sudo cp /tmp/cgroup-mount.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable cgroup-mount.service && sudo systemctl start cgroup-mount.service"

# Restart Nomad
echo "Restarting Nomad service..."
ssh ${RPI_USER}@${RPI_HOST} "sudo systemctl restart nomad"

echo "✅ Java and Exec drivers should now be fixed on Raspberry Pi"
echo "Check status with: nomad node status \$(curl -s http://localhost:4646/v1/nodes | jq -r '.[] | select(.Name==\"ras\") | .ID')" 