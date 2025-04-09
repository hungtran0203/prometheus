#!/bin/bash

# Fix cgroups for Nomad drivers on Raspberry Pi
# This script tries several approaches to fix cgroup issues

# Configuration options
RPI_HOST="ras.local"
RPI_USER="hung"

# Print script banner
echo "========================================"
echo "Fixing cgroups for Nomad drivers on Raspberry Pi"
echo "========================================"

# Try a different approach with cgroups directly
echo "Trying direct cgroup fixes..."

# Create a script to run on the Raspberry Pi
cat > /tmp/fix-cgroups-raspi.sh << 'EOF'
#!/bin/bash

# Create mount points if they don't exist
sudo mkdir -p /sys/fs/cgroup/memory
sudo mkdir -p /sys/fs/cgroup/cpu

# Try to mount cgroups
if ! mount | grep -q "cgroup on /sys/fs/cgroup/memory"; then
  echo "Mounting memory cgroup subsystem..."
  sudo mount -t cgroup -o memory none /sys/fs/cgroup/memory || echo "Failed to mount memory cgroup"
fi

if ! mount | grep -q "cgroup on /sys/fs/cgroup/cpu"; then
  echo "Mounting CPU cgroup subsystem..."
  sudo mount -t cgroup -o cpu none /sys/fs/cgroup/cpu || echo "Failed to mount CPU cgroup"
fi

# Create a cgconfig.conf file
cat > /tmp/cgconfig.conf << 'ENDCFG'
mount {
  cpuset = /sys/fs/cgroup/cpuset;
  cpu = /sys/fs/cgroup/cpu;
  cpuacct = /sys/fs/cgroup/cpuacct;
  memory = /sys/fs/cgroup/memory;
  devices = /sys/fs/cgroup/devices;
  freezer = /sys/fs/cgroup/freezer;
  net_cls = /sys/fs/cgroup/net_cls;
  blkio = /sys/fs/cgroup/blkio;
}
ENDCFG

sudo mv /tmp/cgconfig.conf /etc/cgconfig.conf

# Install cgroup tools if not already installed
if ! which cgconfigparser > /dev/null; then
  echo "Installing cgroup tools..."
  sudo apt-get update
  sudo apt-get install -y cgroup-tools
fi

# Try parsing the config
if which cgconfigparser > /dev/null; then
  echo "Parsing cgroup config..."
  sudo cgconfigparser -l /etc/cgconfig.conf || echo "Failed to parse cgroup config"
fi

# Update Nomad config to use no_cgroups option
cat > /tmp/ras-client.hcl << 'ENDCFG'
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
  }
}

consul {
  enabled = false
}
ENDCFG

sudo mv /tmp/ras-client.hcl /etc/nomad.d/nomad.hcl

# Create a boot script to mount cgroups at startup
cat > /tmp/mount-cgroups.sh << 'ENDSCRIPT'
#!/bin/bash
mkdir -p /sys/fs/cgroup/memory
mkdir -p /sys/fs/cgroup/cpu
mkdir -p /sys/fs/cgroup/cpuset
mkdir -p /sys/fs/cgroup/blkio
mkdir -p /sys/fs/cgroup/devices
mkdir -p /sys/fs/cgroup/freezer

mount -t cgroup -o memory none /sys/fs/cgroup/memory
mount -t cgroup -o cpu none /sys/fs/cgroup/cpu
mount -t cgroup -o cpuset none /sys/fs/cgroup/cpuset
mount -t cgroup -o blkio none /sys/fs/cgroup/blkio
mount -t cgroup -o devices none /sys/fs/cgroup/devices
mount -t cgroup -o freezer none /sys/fs/cgroup/freezer
ENDSCRIPT

sudo mv /tmp/mount-cgroups.sh /usr/local/bin/mount-cgroups.sh
sudo chmod +x /usr/local/bin/mount-cgroups.sh

# Create a systemd service to mount cgroups at boot
cat > /tmp/mount-cgroups.service << 'ENDSERVICE'
[Unit]
Description=Mount cgroup subsystems
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-cgroups.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
ENDSERVICE

sudo mv /tmp/mount-cgroups.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mount-cgroups.service
sudo systemctl start mount-cgroups.service

# Restart Nomad
sudo systemctl restart nomad
EOF

# Make the script executable and copy it to the Raspberry Pi
chmod +x /tmp/fix-cgroups-raspi.sh
scp /tmp/fix-cgroups-raspi.sh ${RPI_USER}@${RPI_HOST}:/tmp/

# Run the script on the Raspberry Pi
echo "Executing fix script on Raspberry Pi..."
ssh ${RPI_USER}@${RPI_HOST} "chmod +x /tmp/fix-cgroups-raspi.sh && /tmp/fix-cgroups-raspi.sh"

echo "✅ Cgroup fixes applied on Raspberry Pi"
echo "Waiting for Nomad to restart..."
sleep 10

# Check if the drivers are now healthy
echo "Checking driver status..."
RASPI_ID=$(curl -s http://localhost:4646/v1/nodes | jq -r '.[] | select(.Name=="ras") | .ID')
curl -s http://localhost:4646/v1/node/${RASPI_ID} | jq '.Drivers.exec.Healthy, .Drivers.java.Healthy' 