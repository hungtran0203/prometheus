#!/bin/bash

# Unified log forwarder that sends logs to a single Vector port with app identification
# Usage: ./scripts/utils/unified_log_forwarder.sh APP_NAME "command to run"
# Example: ./scripts/utils/unified_log_forwarder.sh myapp "node server.js"

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 APP_NAME 'command to run'"
  echo "Example: $0 myapp 'node server.js'"
  exit 1
fi

APP_NAME="$1"
shift
COMMAND="$@"

# Single unified Vector TCP port
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
      # Add app identifier to the log line
      TAGGED_LINE="[app:$APP_NAME] $line"
      
      # Use different netcat command depending on OS
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific netcat command
        printf "%s\n" "$TAGGED_LINE" | nc localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
      else
        # Linux netcat command
        printf "%s\n" "$TAGGED_LINE" | nc -q0 localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
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
echo "📋 Logs will be forwarded to Vector on port $VECTOR_PORT with identifier [app:$APP_NAME]"

# Test connection to Vector
echo "Testing connection to Vector..."
TIMEOUT_CMD="timeout"
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
  else
    echo "⚠️ 'timeout' command not found, connection test will be skipped."
    TIMEOUT_CMD=""
  fi
fi

if [ -n "$TIMEOUT_CMD" ]; then
  if $TIMEOUT_CMD 2 bash -c "echo 'TEST CONNECTION' | nc localhost $VECTOR_PORT" 2>/dev/null; then
    echo "✅ Successfully connected to Vector on port $VECTOR_PORT"
  else
    echo "⚠️ Could not connect to Vector on port $VECTOR_PORT"
    echo "⚠️ Make sure Vector is running with the unified configuration."
    echo "⚠️ Run './scripts/utils/setup_unified_vector.sh' to set up Vector with the unified port."
    exit 1
  fi
fi

# Run the command and capture its output
$COMMAND 2>&1 | tee >(forward_log) &
COMMAND_PID=$!

echo "✅ Process started with PID: $COMMAND_PID"
echo "🔍 Check logs in Grafana: http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bapp%3D%5C%22$APP_NAME%5C%22%7D%22%7D%5D%7D"

wait $COMMAND_PID
echo "✅ Process completed." 