#!/bin/bash

# Get stdout and stderr of a running process
# Usage: ./scripts/utils/get_process_logs.sh PID
# Works on both macOS and Linux

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 PID"
  echo "Example: $0 12345"
  exit 1
fi

PID="$1"

# Verify PID exists
if ! ps -p "$PID" > /dev/null; then
  echo "❌ Error: Process with PID $PID does not exist"
  exit 1
fi

# Get process information
PROCESS_CMD=$(ps -p "$PID" -o command= | head -1 | tr -d '\n')
PROCESS_NAME=$(ps -p "$PID" -o comm= | tr -d '\n')
PROCESS_USER=$(ps -p "$PID" -o user= | tr -d '\n')

echo "🔍 Examining process $PID:"
echo "  • Command: $PROCESS_CMD"
echo "  • Name: $PROCESS_NAME" 
echo "  • User: $PROCESS_USER"

# Function to find file descriptors for stdout/stderr
find_fds() {
  local pid=$1
  local fds=""
  
  # Try to find stdout/stderr file descriptors
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux - use /proc filesystem
    if [ -d "/proc/$pid/fd" ]; then
      echo "📋 Examining file descriptors in /proc/$pid/fd"
      # Find stdout (fd 1) and stderr (fd 2)
      if [ -L "/proc/$pid/fd/1" ]; then
        echo "  • STDOUT (fd 1): $(readlink /proc/$pid/fd/1)"
      fi
      if [ -L "/proc/$pid/fd/2" ]; then
        echo "  • STDERR (fd 2): $(readlink /proc/$pid/fd/2)"
      fi
      
      # Try to read fd content if possible
      if [ -r "/proc/$pid/fd/1" ]; then
        echo -e "\n--- STDOUT Content ---"
        cat /proc/$pid/fd/1 2>/dev/null || echo "(Could not read STDOUT content)"
      fi
      if [ -r "/proc/$pid/fd/2" ]; then
        echo -e "\n--- STDERR Content ---"
        cat /proc/$pid/fd/2 2>/dev/null || echo "(Could not read STDERR content)"
      fi
    else
      echo "  • No /proc filesystem access for PID $pid"
    fi
  fi
  
  # For both macOS and Linux - try lsof
  if command -v lsof >/dev/null 2>&1; then
    echo -e "\n📋 Finding open files with lsof:"
    lsof -p $pid 2>/dev/null | grep -E "^$PROCESS_NAME.*\s(txt|cwd|[0-9]+[rw])" | head -10 || echo "  • No relevant files found"
    
    # Get specific details for stdout/stderr
    echo -e "\n📋 File descriptors for STDOUT (1) and STDERR (2):"
    lsof -p $pid -a -d 1,2 2>/dev/null || echo "  • Could not find STDOUT/STDERR file descriptors"
  fi
}

# Find log files and stdout/stderr
find_log_files() {
  local pid=$1
  local log_files=""
  
  echo -e "\n📋 Searching for log files:"
  
  # Find open files for the process
  if command -v lsof >/dev/null 2>&1; then
    # Find .log files opened by the process
    log_files=$(lsof -p $pid 2>/dev/null | grep -E '\.log|stdout|stderr' | awk '{print $9}')
    
    # Also check standard locations based on process name
    local common_log_dirs=("/var/log" "/tmp" "logs" "log" ".")
    
    for dir in "${common_log_dirs[@]}"; do
      if [ -d "$dir" ]; then
        local found_logs=$(find "$dir" -name "*${PROCESS_NAME}*" -o -name "*.log" 2>/dev/null | head -5)
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
  
  # Display and read log files
  if [ -n "$log_files" ]; then
    echo "$log_files" | sort | uniq | while read -r file; do
      if [ -f "$file" ] && [ -r "$file" ]; then
        echo "  • $file (readable)"
        echo -e "\n--- Last 10 lines from $file ---"
        tail -n 10 "$file" 2>/dev/null || echo "(Could not read file)"
        echo -e "--- End of $file ---\n"
      elif [ -f "$file" ]; then
        echo "  • $file (not readable)"
      fi
    done
  else
    echo "  • No log files found"
  fi
}

# Try system-specific log access
system_logs() {
  local pid=$1
  
  echo -e "\n📋 Checking system logs for process $PROCESS_NAME (PID $pid):"
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - try using log command
    echo "  • Fetching recent console logs (macOS):"
    log show --predicate "process == \"$PROCESS_NAME\"" --last 2m 2>/dev/null | tail -20 || echo "  • No logs found in system log"
    
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux - try journalctl
    if command -v journalctl >/dev/null 2>&1; then
      echo "  • Fetching recent journal logs (Linux):"
      journalctl _PID=$pid --no-pager --since "2 minutes ago" 2>/dev/null | tail -20 || echo "  • No logs found in journal"
    else
      echo "  • journalctl not available"
    fi
  fi
}

# Use strace/dtruss as a last resort (might require sudo)
try_trace() {
  local pid=$1
  
  echo -e "\n📋 Attempting to trace process output (may require elevated privileges):"
  
  if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v strace >/dev/null 2>&1; then
    echo "  • You can try: sudo strace -e write -p $pid -s 1024"
    echo "  • Running strace for 5 seconds (Ctrl+C to stop early):"
    timeout 5 strace -e write -p $pid -s 1024 2>&1 | grep -E 'write\(1|write\(2' | head -10 || echo "  • Could not attach with strace"
    
  elif [[ "$OSTYPE" == "darwin"* ]] && command -v dtruss >/dev/null 2>&1; then
    echo "  • You can try: sudo dtruss -t write -p $pid"
    echo "  • Note: dtruss requires System Integrity Protection (SIP) to be disabled"
  fi
}

# Main execution
echo -e "\n=== Process Information ==="
find_fds $PID
find_log_files $PID
system_logs $PID
try_trace $PID

echo -e "\n=== Summary ==="
echo "✅ Process $PID ($PROCESS_NAME) log inspection complete"
echo "💡 If you want to continuously monitor this process, try:"
echo "  just forward-logs $(lsof -i -P -n | grep $PID | grep LISTEN | grep -Eo ':[0-9]+' | tr -d ':' | head -1 || echo '<port>')" 