#!/bin/bash

# Stop any existing Nomad processes
pkill nomad || true

# Start Nomad in the background
nohup nomad agent -config=config/local/nomad.hcl > nomad.log 2>&1 &

# Wait a moment to ensure the process started
sleep 5

# Check if the process is running
if pgrep -x "nomad" > /dev/null; then
    echo "Nomad started successfully. PID: $(pgrep -x "nomad")"
    echo "Check nomad.log for output"
else
    echo "Failed to start Nomad. Check nomad.log for errors"
    exit 1
fi 