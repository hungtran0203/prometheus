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

# Verify PID exists
if ! ps -p "$PID" > /dev/null; then
  echo "❌ Error: Process with PID $PID does not exist"
  exit 1
fi

# Get process command for identification
PROCESS_CMD=$(ps -p "$PID" -o command= | head -1 | tr -d '\n')
PROCESS_NAME=$(ps -p "$PID" -o comm= | tr -d '\n')
echo "📋 Process command: $PROCESS_CMD"
echo "📋 Process name: $PROCESS_NAME"

# Test Vector connection
echo "🔄 Testing connection to Vector on port $VECTOR_PORT..."
if echo "[port:$PORT] Test connection from log forwarder" | nc -w 1 localhost $VECTOR_PORT 2>/dev/null; then
  echo "✅ Successfully connected to Vector on port $VECTOR_PORT"
else
  echo "❌ Error: Could not connect to Vector on port $VECTOR_PORT"
  echo "Please make sure Vector is running and listening on port $VECTOR_PORT"
  exit 1
fi

# Find the log files associated with the process
find_log_files() {
  local pid=$1
  local log_files=""
  
  # Find open files for the process
  if command -v lsof >/dev/null 2>&1; then
    # Find .log files opened by the process
    log_files=$(lsof -p $pid 2>/dev/null | grep -E '\.log|stdout|stderr' | awk '{print $9}')
    
    # Also check standard locations based on process name
    local proc_name=$(ps -p $pid -o comm= | tr -d '\n')
    local common_log_dirs=("/var/log" "/tmp" "logs" "log" ".")
    
    for dir in "${common_log_dirs[@]}"; do
      if [ -d "$dir" ]; then
        local found_logs=$(find "$dir" -name "*${proc_name}*" -o -name "*.log" 2>/dev/null | head -5)
        if [ -n "$found_logs" ]; then
          if [ -n "$log_files" ]; then
            log_files="$log_files"$'\n'"$found_logs"
          else
            log_files="$found_logs"
          fi
        fi
      fi
    done
  fi
  
  echo "$log_files"
}

# Look for log files
LOG_FILES=$(find_log_files $PID)
if [ -n "$LOG_FILES" ]; then
  echo "📋 Found potential log files:"
  echo "$LOG_FILES" | while read -r file; do
    if [ -f "$file" ] && [ -r "$file" ]; then
      echo "   - $file (readable)"
    elif [ -f "$file" ]; then
      echo "   - $file (not readable)"
    fi
  done
fi

# Start monitoring instead of direct capture
echo "🔄 Starting log monitoring for process on port $PORT..."

# Function to clean up on exit
cleanup() {
  echo "🛑 Stopping log forwarding..."
  exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Send logs to Vector
send_log() {
  local message="$1"
  echo "[port:$PORT] $message" | nc -w 1 localhost $VECTOR_PORT
  echo "$message"
}

# Function to get process info and logs
log_process_info() {
  local pid=$1
  local port=$2
  
  # Get process CPU and memory usage
  local cpu_mem=$(ps -p $pid -o %cpu,%mem | tail -1)
  local cpu=$(echo $cpu_mem | awk '{print $1}')
  local mem=$(echo $cpu_mem | awk '{print $2}')
  
  # Get open connections to this port
  local connections=$(lsof -i :$port -n | wc -l | xargs)
  
  # Send the process stats
  local message="Process monitoring: PID=$pid, CPU=${cpu}%, MEM=${mem}%, Connections=$connections"
  send_log "$message"
  
  # Try to get stdout/stderr by checking log files
  if [ -n "$LOG_FILES" ]; then
    local logs_found=false
    echo "$LOG_FILES" | while read -r file; do
      if [ -f "$file" ] && [ -r "$file" ]; then
        # Get the last 5 lines of the log file if modified in the last minute
        if [ $(find "$file" -mtime -1m 2>/dev/null | wc -l) -gt 0 ]; then
          logs_found=true
          local last_lines=$(tail -n 5 "$file" 2>/dev/null)
          if [ -n "$last_lines" ]; then
            echo "$last_lines" | while read -r line; do
              send_log "Log: $line"
            done
          fi
        fi
      fi
    done
    
    if [ "$logs_found" = false ]; then
      send_log "No recent log entries found in monitored files"
    fi
  fi
  
  # Try to get console output for the process (macOS specific)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, try to get console logs for the app
    local console_logs=$(log show --predicate "process == \"$PROCESS_NAME\"" --last 1m 2>/dev/null | tail -5)
    if [ -n "$console_logs" ]; then
      echo "$console_logs" | while read -r line; do
        send_log "Console: $line"
      done
    fi
  fi
}

echo "✅ Log monitoring started! Press Ctrl+C to stop."
echo "🔍 Check logs in Grafana: http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bmessage%3D~%5C%22.*%5C%5C%5Bport%3A$PORT%5C%5C%5D.*%5C%22%7D%22%7D%5D%7D"

# Monitor process and send logs periodically
counter=0
while true; do
  counter=$((counter + 1))
  log_process_info $PID $PORT
  
  # Check if process is still running
  if ! ps -p "$PID" > /dev/null; then
    echo "❌ Process with PID $PID is no longer running. Exiting."
    exit 1
  fi
  
  sleep 5
done 