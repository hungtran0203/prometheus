#!/bin/bash

# Script to recreate all app exporter configurations from template
# Usage: ./scripts/recreate_app_exporters.sh

echo "🔄 Recreating all app exporter configurations from template..."

# Check if template exists
if [ ! -f "templates/app_exporter.yml.template" ]; then
    echo "❌ Error: Template file 'templates/app_exporter.yml.template' not found!"
    exit 1
fi

# Find all app configuration files
for app_file in docker-compose-app/*.yml; do
    if [ -f "$app_file" ]; then
        app_name=$(basename "$app_file" .yml)
        echo "🔧 Recreating configuration for $app_name..."
        
        # Extract port from the nginx configuration
        port=$(grep -o 'scrape-uri=http://dev-proxy:[0-9]*' "$app_file" | grep -o '[0-9]*')
        
        if [ -z "$port" ]; then
            echo "⚠️ Warning: Could not extract port for $app_name, skipping."
            continue
        fi
        
        # Use the template to recreate the configuration
        cat templates/app_exporter.yml.template | \
            sed "s/{{APP_NAME}}/$app_name/g" | \
            sed "s/{{PORT}}/$port/g" > "$app_file"
            
        echo "✅ Recreated configuration for $app_name with port $port"
    fi
done

echo "🔄 All app exporter configurations have been recreated."
echo "🔄 Run 'just update-restart-proxy-apps' to apply the changes."

exit 0 