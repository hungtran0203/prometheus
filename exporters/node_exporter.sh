#!/bin/bash

# Variables
NODE_EXPORTER_VERSION="1.7.0"
NODE_EXPORTER_ARCH="darwin-arm64"
NODE_EXPORTER_DIR="$HOME/node_exporter"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}.tar.gz"
NODE_EXPORTER_PORT=9100

# Create directory if it doesn't exist
mkdir -p "$NODE_EXPORTER_DIR"

# Check if node_exporter is already installed
if [ ! -f "$NODE_EXPORTER_DIR/node_exporter" ]; then
  echo "Downloading and installing node_exporter $NODE_EXPORTER_VERSION for macOS..."
  
  # Download node_exporter
  curl -L "$NODE_EXPORTER_URL" -o "${NODE_EXPORTER_DIR}/node_exporter.tar.gz"
  
  # Extract node_exporter
  tar -xzf "${NODE_EXPORTER_DIR}/node_exporter.tar.gz" -C "$NODE_EXPORTER_DIR" --strip-components=1
  
  # Make executable
  chmod +x "${NODE_EXPORTER_DIR}/node_exporter"
  
  # Clean up
  rm "${NODE_EXPORTER_DIR}/node_exporter.tar.gz"
  
  echo "node_exporter installed successfully!"
else
  echo "node_exporter already installed."
fi

# Kill any running node_exporter processes
pkill -f "node_exporter" || true
echo "Stopped any running node_exporter instances."

# Start node_exporter with macOS-specific collectors
echo "Starting node_exporter on port $NODE_EXPORTER_PORT..."
"$NODE_EXPORTER_DIR/node_exporter" \
  --web.listen-address=":$NODE_EXPORTER_PORT" \
  --collector.filesystem.mount-points-exclude="^/(dev|proc|sys|var/lib/docker/.+)($|/)" \
  --collector.textfile.directory="$NODE_EXPORTER_DIR/textfile_collector" \
  --collector.cpu \
  --collector.diskstats \
  --collector.loadavg \
  --collector.meminfo \
  --collector.netstat \
  --collector.netdev \
  --collector.filesystem \
  --collector.uname &

echo "node_exporter started. Metrics available at http://localhost:$NODE_EXPORTER_PORT/metrics"
echo "Add the following to your Prometheus configuration to scrape these metrics:"
echo ""
echo "  - job_name: 'node_exporter_mac'"
echo "    static_configs:"
echo "      - targets: ['host.docker.internal:$NODE_EXPORTER_PORT']" 