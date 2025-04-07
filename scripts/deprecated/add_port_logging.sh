#!/bin/bash

# Script to add port-based log collection to Vector configuration
# Usage: ./scripts/add_port_logging.sh port [process_name] [log_path]

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 port [process_name] [log_path]"
  echo "Example: $0 3000"
  exit 1
fi

PORT="$1"
PROCESS_NAME="${2:-}"  # Optional process name
LOG_PATH="${3:-}"      # Optional log file path

# If process name is not provided, use a default based on port
if [ -z "$PROCESS_NAME" ]; then
  PROCESS_NAME="port${PORT}"
  echo "ℹ️ Using default process name: $PROCESS_NAME"
fi

echo "🔧 Adding log collection for process on port $PORT with name $PROCESS_NAME..."

# Create vector directory if it doesn't exist
mkdir -p vector

# Check if vector.toml exists, create from template if not
if [ ! -f "vector/vector.toml" ]; then
  if [ -f "templates/vector.toml.template" ]; then
    echo "📋 Creating vector.toml from template..."
    cp templates/vector.toml.template vector/vector.toml
  else
    echo "❌ Error: Vector template not found at templates/vector.toml.template"
    exit 1
  fi
fi

# Create a temporary file for our new config
TMP_FILE=$(mktemp)

# Add file source if provided
if [ -n "$LOG_PATH" ]; then
  echo "📄 Using file source for log collection from: $LOG_PATH"
  SOURCE_TYPE="file"
  SOURCE_NAME="file_${PORT}"
  SOURCE_CONFIG="
[sources.file_${PORT}]
type = \"file\"
include = [\"$LOG_PATH\"]
read_from = \"beginning\"
"
else
  echo "📄 Using socket source for log collection"
  SOURCE_TYPE="socket"
  SOURCE_NAME="socket_${PORT}"
  SOURCE_CONFIG="
[sources.socket_${PORT}]
type = \"socket\"
mode = \"tcp\"
address = \"0.0.0.0:4${PORT}\"
"
fi

# Create the new configuration file
cat > "$TMP_FILE" << EOF
# Vector configuration for logging proxy apps
# This file is auto-generated - do not edit manually

# Source for collecting logs from Docker
[sources.docker_source]
type = "docker_logs"
docker_host = "unix:///var/run/docker.sock"
include_labels = ["com.docker.compose.service"]
auto_partial_merge = true

# Source for collecting logs from port $PORT
$SOURCE_CONFIG

# Transform for local process on port $PORT
[transforms.port_${PORT}_parser]
type = "remap"
inputs = ["${SOURCE_NAME}"]
source = '''
  .app = "${PROCESS_NAME}"
  .target_port = "${PORT}"
  .host = get_hostname() ?? "localhost"
'''

# Output logs to Loki
[sinks.loki]
type = "loki"
inputs = ["docker_source", "port_${PORT}_parser"]
endpoint = "http://loki:3100"
encoding.codec = "json"
labels.app = "{{ app }}"
labels.target_port = "{{ target_port }}"
labels.host = "{{ host }}"
EOF

# Replace the existing vector.toml with our new config
mv "$TMP_FILE" vector/vector.toml

echo "✅ Added log collection for process on port $PORT with name $PROCESS_NAME"
echo "🔄 To send logs to this port, direct your application to log to TCP port 4${PORT}"
echo "🔄 Example: netcat localhost 4${PORT}"
exit 0 