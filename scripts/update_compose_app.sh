#!/bin/bash

# This script rebuilds the docker-compose-app.yml file based on all YML files in the docker-compose-app directory

# Check if docker-compose-app directory exists
if [ ! -d "docker-compose-app" ]; then
    echo "Error: docker-compose-app directory not found!"
    exit 1
fi

# Create the header for the docker-compose-app.yml file
cat > docker-compose-app.yml << EOF
name: app-exporters

# This is the main docker-compose file for all app exporters
# It imports all individual app configurations from docker-compose-app/ directory

# Import all app configurations
include:
EOF

# Add all YML files from the docker-compose-app directory
for file in docker-compose-app/*.yml; do
    if [ -f "$file" ]; then
        # Get just the filename without path
        app_file=$(basename "$file")
        echo "  - docker-compose-app/$app_file" >> docker-compose-app.yml
    fi
done

# Add the footer with network configuration
cat >> docker-compose-app.yml << EOF

# Common networks configuration
networks:
  monitoring_network:
    external: true
    name: prometheus_monitoring_network
EOF

echo "✅ Updated docker-compose-app.yml with all available app exporters."
exit 0 