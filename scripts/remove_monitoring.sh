#!/usr/bin/env bash
# Script to remove monitoring for an application
# Usage: ./remove_monitoring.sh app_name port

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 app_name port"
  echo "Example: $0 myapp 3005"
  exit 1
fi

APP_NAME="$1"
PORT="$2"
APP_NAME_CAP=$(echo "$APP_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

echo "🔧 Removing monitoring for $APP_NAME_CAP on port $PORT"

# 0. Stop and remove the container immediately
echo "🔧 Stopping and removing the exporter container if it exists..."
CONTAINER_NAME="${APP_NAME}-exporter"
if docker ps -a | grep -w "$CONTAINER_NAME" > /dev/null; then
  docker stop $CONTAINER_NAME 2>/dev/null || true
  docker rm $CONTAINER_NAME 2>/dev/null || true
  echo "✅ Container $CONTAINER_NAME stopped and removed"
else
  echo "⚠️ Container $CONTAINER_NAME not found, trying with docker compose down..."
  docker compose -f docker-compose-app.yml down --remove-orphans
fi

# 1. Remove the server block from servers directory
echo "🔧 Removing Nginx configuration..."
SERVER_FILE="nginx/servers/${APP_NAME}.conf"
if [ -f "$SERVER_FILE" ]; then
  rm "$SERVER_FILE"
  echo "✅ Server configuration removed: $SERVER_FILE"
else
  echo "⚠️ Server file for $APP_NAME not found at $SERVER_FILE"
fi

# 2. Remove port mapping from main docker-compose.yml
echo "🔧 Removing port mapping from docker-compose.yml..."
grep -v "\"$PORT:$PORT\".*# $APP_NAME port" docker-compose.yml > docker-compose.yml.new
mv docker-compose.yml.new docker-compose.yml

# 3. Remove the exporter service configuration file
echo "🔧 Removing exporter service configuration..."
EXPORTER_FILE="docker-compose-app/${APP_NAME}.yml"
if [ -f "$EXPORTER_FILE" ]; then
  rm "$EXPORTER_FILE"
  echo "✅ Exporter configuration removed: $EXPORTER_FILE"
  
  # Also update the docker-compose-app.yml file
  if [ -f docker-compose-app.yml ]; then
    # Update docker-compose-app.yml using the helper script
    ./scripts/update_compose_app.sh
    echo "✅ Updated docker-compose-app.yml"
  fi
else
  echo "⚠️ Exporter configuration for $APP_NAME not found at $EXPORTER_FILE"
fi

# 4. Remove the job from prometheus conf.d directory
echo "🔧 Removing Prometheus job configuration..."
CONFIG_FILE="prometheus/conf.d/${APP_NAME}.yml"
if [ -f "$CONFIG_FILE" ]; then
  rm "$CONFIG_FILE"
  echo "✅ Prometheus configuration removed: $CONFIG_FILE"
else
  echo "⚠️ Prometheus configuration for $APP_NAME not found at $CONFIG_FILE"
fi

# 5. Remove the dashboard file
echo "🔧 Removing Grafana dashboard..."
DASHBOARD_FILE="grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json"
if [ -f "$DASHBOARD_FILE" ]; then
  rm "$DASHBOARD_FILE"
  echo "✅ Dashboard removed: $DASHBOARD_FILE"
else
  echo "⚠️ Dashboard file not found: $DASHBOARD_FILE"
fi

# 6. Update the status page - remove from status endpoints list
echo "🔧 Updating status page..."
# Remove the app from the status endpoints list
grep -v "<li><a href=\"/${APP_NAME}_status\">/${APP_NAME}_status</a>" nginx/servers/main.conf > nginx/servers/main.conf.new
mv nginx/servers/main.conf.new nginx/servers/main.conf

# Remove from port forwarding list
grep -v "<li><strong>$PORT.*: $APP_NAME_CAP</li>" nginx/servers/main.conf > nginx/servers/main.conf.new
mv nginx/servers/main.conf.new nginx/servers/main.conf

# Update default route string in status page
sed -i.bak "s/ $PORT -> .* ($APP_NAME_CAP)//" nginx/servers/main.conf
rm -f nginx/servers/main.conf.bak

echo "✅ Done! Configuration files have been updated." 