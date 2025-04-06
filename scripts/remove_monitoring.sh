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

# 1. Remove the server block from nginx.conf
echo "🔧 Removing Nginx configuration..."
# Find the start and end of the server block for this app
START_LINE=$(grep -n "# Port forwarding for $APP_NAME app" nginx/nginx.conf | cut -d: -f1)
if [ -z "$START_LINE" ]; then
  echo "⚠️ Server block for $APP_NAME not found in nginx/nginx.conf"
else
  # Find the end of this server block (the next closing brace)
  END_LINE=$(tail -n +$START_LINE nginx/nginx.conf | grep -n "^}" | head -1 | cut -d: -f1)
  if [ -n "$END_LINE" ]; then
    END_LINE=$((START_LINE + END_LINE))
    
    # Create new file without this server block
    head -n $((START_LINE-1)) nginx/nginx.conf > nginx/nginx.conf.new
    tail -n +$((END_LINE+1)) nginx/nginx.conf >> nginx/nginx.conf.new
    mv nginx/nginx.conf.new nginx/nginx.conf
    echo "✅ Server block removed from nginx/nginx.conf"
  else
    echo "⚠️ Could not find end of server block for $APP_NAME in nginx/nginx.conf"
  fi
fi

# 2. Remove port mapping from main docker-compose.yml
echo "🔧 Removing port mapping from docker-compose.yml..."
grep -v "\"$PORT:$PORT\".*# $APP_NAME port" docker-compose.yml > docker-compose.yml.new
mv docker-compose.yml.new docker-compose.yml

# 3. Remove the exporter service from docker-compose.proxy-apps.yml
echo "🔧 Removing exporter service from docker-compose.proxy-apps.yml..."
if [ -f docker-compose.proxy-apps.yml ]; then
  # Create a temporary file without the app exporter
  grep -v -A 12 "# $APP_NAME app metrics exporter" docker-compose.proxy-apps.yml > docker-compose.proxy-apps.yml.tmp
  mv docker-compose.proxy-apps.yml.tmp docker-compose.proxy-apps.yml
  echo "✅ Exporter service removed from docker-compose.proxy-apps.yml"
else
  echo "⚠️ docker-compose.proxy-apps.yml not found"
fi

# 4. Remove the job from prometheus.yml
echo "🔧 Removing Prometheus job configuration..."
# Find the start of the job config for this app
START_LINE=$(grep -n "# Specific metrics for the $APP_NAME application" prometheus/prometheus.yml | cut -d: -f1)
if [ -z "$START_LINE" ]; then
  echo "⚠️ Job configuration for $APP_NAME not found in prometheus/prometheus.yml"
else
  # Find the end of this job config (the next job or the end of the file)
  END_LINE=$(tail -n +$START_LINE prometheus/prometheus.yml | grep -n "# Specific metrics" | head -1 | cut -d: -f1)
  if [ -n "$END_LINE" ]; then
    END_LINE=$((START_LINE + END_LINE - 2))
  else
    # If no next job, look for the end of the scrape_configs
    END_LINE=$(tail -n +$START_LINE prometheus/prometheus.yml | grep -n "^  # Network monitoring" | head -1 | cut -d: -f1)
    if [ -n "$END_LINE" ]; then
      END_LINE=$((START_LINE + END_LINE - 2))
    else
      # If still not found, go to the end of the file
      END_LINE=$(wc -l < prometheus/prometheus.yml)
    fi
  fi
  
  # Create new file without this job config
  head -n $((START_LINE-1)) prometheus/prometheus.yml > prometheus/prometheus.yml.new
  tail -n +$((END_LINE+1)) prometheus/prometheus.yml >> prometheus/prometheus.yml.new
  mv prometheus/prometheus.yml.new prometheus/prometheus.yml
  echo "✅ Job configuration removed from prometheus/prometheus.yml"
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
grep -v "<li><a href=\"/${APP_NAME}_status\">/${APP_NAME}_status</a>" nginx/nginx.conf > nginx/nginx.conf.new
mv nginx/nginx.conf.new nginx/nginx.conf

# Remove from port forwarding list
grep -v "<li><strong>$PORT.*: $APP_NAME_CAP</li>" nginx/nginx.conf > nginx/nginx.conf.new
mv nginx/nginx.conf.new nginx/nginx.conf

# Update default route string in status page
sed -i.bak "s/ $PORT -> .* ($APP_NAME_CAP)//" nginx/nginx.conf
rm -f nginx/nginx.conf.bak

echo "✅ Done! Configuration files have been updated." 