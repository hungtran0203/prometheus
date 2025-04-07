#!/bin/bash

# Run a command and forward its output to Vector's TCP socket
# Usage: ./scripts/utils/run_with_logs.sh PORT "command to run"
# Example: ./scripts/utils/run_with_logs.sh 3000 "node server.js"

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 PORT 'command to run'"
  echo "Example: $0 3000 'node server.js'"
  exit 1
fi

PORT="$1"
shift
COMMAND="$@"

# Vector TCP port is now unified at 45000 for all applications
VECTOR_PORT="45000"
echo "🔄 Will forward logs to Vector on unified port $VECTOR_PORT"

# Check if netcat is available
if ! command -v nc >/dev/null 2>&1; then
  echo "❌ Error: 'nc' (netcat) command not found. Please install it."
  exit 1
fi

# Function to forward logs to Vector
forward_log() {
  while read -r line; do
    if [ -n "$line" ]; then
      # Use different netcat command depending on OS
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific netcat command
        printf "%s\n" "$line" | nc localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
      else
        # Linux netcat command
        printf "%s\n" "$line" | nc -q0 localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
      fi
    fi
  done
}

# Function to clean up on exit
cleanup() {
  echo "🛑 Stopping the process and log forwarding..."
  kill $COMMAND_PID 2>/dev/null || true
  exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

echo "🚀 Starting command: $COMMAND"
echo "📋 Logs will be forwarded to Vector on port $VECTOR_PORT"

# Run the command and capture its output
$COMMAND 2>&1 | tee >(forward_log) &
COMMAND_PID=$!

echo "✅ Process started with PID: $COMMAND_PID"
echo "🔍 Check logs in Grafana: http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bapp%3D%5C%22port$PORT%5C%22%7D%22%7D%5D%7D"

wait $COMMAND_PID
echo "✅ Process completed." 