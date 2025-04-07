#!/bin/bash

# Forward logs from a running process to Vector's TCP socket
# Usage: ./scripts/utils/forward_logs.sh PORT [PID]
# If PID is not provided, will attempt to find process listening on PORT

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 PORT [PID]"
  echo "Example: $0 3000"
  echo "Example with PID: $0 3000 12345"
  exit 1
fi

PORT="$1"
PID="${2:-}"

# If PID is not provided, try to find it
if [ -z "$PID" ]; then
  echo "No PID provided, trying to find process listening on port $PORT..."
  
  # Use lsof to find the process ID
  if command -v lsof >/dev/null 2>&1; then
    PID=$(lsof -i :$PORT -t 2>/dev/null)
  # Fallback to netstat if lsof is not available
  elif command -v netstat >/dev/null 2>&1; then
    PID=$(netstat -tunlp 2>/dev/null | grep ":$PORT " | awk '{print $7}' | cut -d/ -f1)
  fi

  if [ -z "$PID" ]; then
    echo "❌ Error: Could not find process listening on port $PORT"
    echo "Please provide PID manually: $0 $PORT <PID>"
    exit 1
  fi
  
  echo "✅ Found process with PID: $PID"
fi

# Vector TCP port is now unified at 45000 for all applications
VECTOR_PORT="45000"
echo "🔄 Will forward logs to Vector on unified port $VECTOR_PORT"

# Create a named pipe for stdout
STDOUT_PIPE="/tmp/stdout_pipe_$PORT"
if [ -e "$STDOUT_PIPE" ]; then
  rm "$STDOUT_PIPE"
fi
mkfifo "$STDOUT_PIPE"

# Verify PID exists
if ! ps -p "$PID" > /dev/null; then
  echo "❌ Error: Process with PID $PID does not exist"
  rm "$STDOUT_PIPE"
  exit 1
fi

# Get process command for identification
PROCESS_CMD=$(ps -p "$PID" -o command= | head -1 | tr -d '\n')
echo "📋 Process command: $PROCESS_CMD"

# Start forwarding in background
echo "🔄 Starting log forwarding for PID $PID to Vector port $VECTOR_PORT..."

# Function to clean up on exit
cleanup() {
  echo "🛑 Stopping log forwarding..."
  if [ -e "$STDOUT_PIPE" ]; then
    rm "$STDOUT_PIPE"
  fi
  # Kill all background processes we started
  if [ -n "$NC_PID" ]; then
    kill $NC_PID 2>/dev/null || true
  fi
  exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Start listening to the named pipe and forwarding to netcat
if command -v nc >/dev/null 2>&1; then
  cat "$STDOUT_PIPE" | while read -r line; do
    # Use different netcat command depending on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS specific netcat command
      printf "[port:$PORT] %s\n" "$line" | nc localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
    else
      # Linux netcat command
      printf "[port:$PORT] %s\n" "$line" | nc -q0 localhost $VECTOR_PORT || echo "⚠️ Failed to send log line to Vector"
    fi
  done &
  NC_PID=$!
else
  echo "❌ Error: 'nc' (netcat) command not found. Please install it."
  cleanup
  exit 1
fi

# Attach to process stderr and stdout
echo "📋 Attaching to process stdout and stderr..."

if command -v strace >/dev/null 2>&1; then
  # Use strace to capture stdout/stderr
  echo "📋 Using strace to capture output..."
  strace -e write -p "$PID" -s 1024 -o "$STDOUT_PIPE" 2>/dev/null &
  STRACE_PID=$!
  echo "✅ Started strace with PID: $STRACE_PID"
elif command -v dtrace >/dev/null 2>&1; then
  # Use dtrace on macOS
  echo "📋 Using dtrace to capture output..."
  dtrace -p "$PID" -n 'syscall::write*:entry /pid == $target && (arg0 == 1 || arg0 == 2)/ { printf("%s", copyinstr(arg1, arg2)); }' > "$STDOUT_PIPE" &
  DTRACE_PID=$!
  echo "✅ Started dtrace with PID: $DTRACE_PID"
else
  echo "❌ Cannot attach to running process - neither strace nor dtrace are available"
  echo "Please install strace (Linux) or ensure dtrace is available (macOS)"
  cleanup
  exit 1
fi

# Print status
echo "✅ Log forwarding started! Press Ctrl+C to stop."
echo "🔍 Check logs in Grafana: http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bapp%3D%5C%22port$PORT%5C%22%7D%22%7D%5D%7D"

# Keep script running until Ctrl+C
while true; do
  sleep 1
done 