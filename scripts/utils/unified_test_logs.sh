#!/bin/bash

# Generate test logs for an application using the unified Vector port
# Usage: ./scripts/utils/unified_test_logs.sh APP_NAME [interval_seconds]
# Example: ./scripts/utils/unified_test_logs.sh myapp 2

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 APP_NAME [interval_seconds]"
  echo "Example: $0 myapp 2"
  exit 1
fi

APP_NAME="$1"
INTERVAL="${2:-1}"  # Default to 1 second if not provided

# Unified Vector TCP port
VECTOR_PORT="45000"
echo "🔄 Will send test logs to Vector on unified port $VECTOR_PORT"

# Check if netcat is available
if ! command -v nc >/dev/null 2>&1; then
  echo "❌ Error: 'nc' (netcat) command not found. Please install it."
  exit 1
fi

# Function to clean up on exit
cleanup() {
  echo "🛑 Stopping test log generation..."
  exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

echo "🚀 Starting test log generation every $INTERVAL second(s)"
echo "📋 Press Ctrl+C to stop"
echo "🔍 Check logs in Grafana: http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bapp%3D%5C%22$APP_NAME%5C%22%7D%22%7D%5D%7D"

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

COUNT=0
while true; do
  COUNT=$((COUNT+1))
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  MESSAGE="[app:$APP_NAME] Test log #$COUNT from $APP_NAME at $TIMESTAMP"
  
  echo "📝 Sending: $MESSAGE"
  # Use different netcat command depending on OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific netcat command
    printf "%s\n" "$MESSAGE" | nc localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
  else
    # Linux netcat command
    printf "%s\n" "$MESSAGE" | nc -q0 localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
  fi
  
  sleep "$INTERVAL"
done 