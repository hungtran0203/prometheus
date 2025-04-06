#!/bin/bash

# This script sets up monitoring for an app in the development environment
# Usage: ./add_monitoring.sh <app_name> <port> <forward_port>

if [ $# -ne 3 ]; then
    echo "Usage: $0 <app_name> <port> <forward_port>"
    exit 1
fi

APP_NAME=$(echo $1 | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
PORT=$2
FORWARD_PORT=$3
APP_NAME_CAPS=$(echo $APP_NAME | sed 's/\b\(.\)/\u\1/g')  # Capitalize first letter

echo "🔧 Setting up monitoring for $APP_NAME_CAPS on port $PORT (forwarding to $FORWARD_PORT)"

# 1. Create Nginx configuration file for the app
echo "🔧 Adding Nginx configuration..."
cat > nginx/servers/$APP_NAME.conf << EOF
# Port forwarding for $APP_NAME app ($PORT -> $FORWARD_PORT)
server {
    listen $PORT;
    
    access_log /var/log/nginx/$APP_NAME\_access.log;
    error_log /var/log/nginx/$APP_NAME\_error.log;

    # Status endpoint for $APP_NAME app
    location = /${APP_NAME}_status {
        stub_status on;
        allow 172.0.0.0/8;
        deny all;
    }

    # Forward all traffic to the actual app
    location / {
        proxy_pass http://host.docker.internal:$FORWARD_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# 2. Update docker-compose.yml with the port mapping
echo "🔧 Updating docker-compose.yml with port mapping..."
PORT_LINE=$(grep -n "# Port mappings for applications" docker-compose.yml | cut -d: -f1)
if [ -n "$PORT_LINE" ]; then
    # Check if the port is already mapped
    PORT_EXISTS=$(grep -n "${PORT}:${PORT}" docker-compose.yml)
    if [ -z "$PORT_EXISTS" ]; then
        # Insert the new port mapping after the comment line
        sed -i.bak "$((PORT_LINE+1))i\\      - \"${PORT}:${PORT}\"    # $APP_NAME port" docker-compose.yml
        rm docker-compose.yml.bak
    fi
fi

# 3. Add the exporter service to docker-compose.proxy-apps.yml
echo "🔧 Adding exporter service to docker-compose.proxy-apps.yml..."

# Check if the exporter service already exists
if ! grep -q "${APP_NAME}-exporter:" docker-compose.proxy-apps.yml; then
    # Add the exporter service to the docker-compose.proxy-apps.yml file
    cat >> docker-compose.proxy-apps.yml << EOF

  # $APP_NAME app metrics exporter
  $APP_NAME-exporter:
    image: nginx/nginx-prometheus-exporter:0.11.0
    container_name: $APP_NAME-exporter
    restart: unless-stopped
    depends_on:
      - nginx
    command:
      - "--nginx.scrape-uri=http://nginx:$PORT/${APP_NAME}_status"
      - "--prometheus.const-label=app=$APP_NAME"
    expose:
      - 9113
EOF
fi

# 4. Update prometheus.yml with the new job
echo "🔧 Updating Prometheus configuration..."

# Create the new job config (use consistent single quotes)
cat > prometheus_config.tmp << EOF
  # Specific metrics for the $APP_NAME application
  - job_name: '${APP_NAME}_proxy'
    scrape_interval: 5s
    static_configs:
      - targets: ['$APP_NAME-exporter:9113']
        labels:
          service: '${APP_NAME}-proxy'
          environment: 'development'
          app: '$APP_NAME'
          port: '$PORT'
EOF

# Check if a job for this app already exists
JOB_EXISTS=$(grep -n "job_name: '${APP_NAME}_proxy'" prometheus/prometheus.yml | cut -d: -f1)
if [ -n "$JOB_EXISTS" ]; then
  echo "⚠️ Job for ${APP_NAME} already exists. Updating existing job..."
  
  # Find the lines containing the start of the job's comment and the job_name line
  JOB_COMMENT=$(grep -n "# Specific metrics for the ${APP_NAME} application" prometheus/prometheus.yml | cut -d: -f1)
  JOB_NAME=$(grep -n "job_name: '${APP_NAME}_proxy'" prometheus/prometheus.yml | cut -d: -f1)
  
  # Use the comment line if it exists, otherwise use the job_name line
  if [ -n "$JOB_COMMENT" ]; then
    JOB_START=$JOB_COMMENT
  else
    JOB_START=$JOB_NAME
  fi
  
  # Find the start of the next job (or end of file if this is the last job)
  NEXT_JOB=$(tail -n +$((JOB_START+1)) prometheus/prometheus.yml | grep -n "job_name:" | head -1 | cut -d: -f1)
  if [ -n "$NEXT_JOB" ]; then
    # If there's a next job, calculate its absolute line number
    END_LINE=$((JOB_START + NEXT_JOB))
    # Get the line before the next job_name line (which should be a comment line or whitespace)
    END_LINE=$((END_LINE - 1))
  else
    # If no next job, use end of file
    END_LINE=$(wc -l < prometheus/prometheus.yml)
  fi
  
  # Replace the existing job with the new one using a cleaner approach
  # Create a new file combining the parts
  head -n $((JOB_START-1)) prometheus/prometheus.yml > prometheus/prometheus.yml.new
  cat prometheus_config.tmp >> prometheus/prometheus.yml.new
  tail -n +$((END_LINE+1)) prometheus/prometheus.yml >> prometheus/prometheus.yml.new
  mv prometheus/prometheus.yml.new prometheus/prometheus.yml
  
else
  # Job doesn't exist, append it to the end of the file
  # First ensure the file ends with a newline
  tail -c1 prometheus/prometheus.yml | read -r _ || echo "" >> prometheus/prometheus.yml
  
  # Then append the new configuration
  cat prometheus_config.tmp >> prometheus/prometheus.yml
  echo "✅ Added new job '${APP_NAME}_proxy' to Prometheus configuration."
fi

rm -f prometheus_config.tmp

# 5. Create a dashboard from template (using nodejs_app_metrics.json as a template)
echo "🔧 Creating Grafana dashboard..."

# Create the dashboard from the template
cp grafana/provisioning/dashboards/nodejs_app_metrics.json grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

# Update the dashboard with the app name
perl -i -pe "s/Node.js/${APP_NAME_CAPS}/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -i -pe "s/nodejs/${APP_NAME}/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

# Update the dashboard ID and UID to avoid conflicts
NEW_UID="${APP_NAME}-$(date +%s | shasum | head -c 8)"
perl -i -pe "s/\"uid\":\s*\"[^\"]*\"/\"uid\": \"$NEW_UID\"/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -i -pe "s/\"id\":\s*\d+/\"id\": null/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

echo "✅ Monitoring has been set up for $APP_NAME_CAPS"
echo "🔍 Grafana dashboard will be available at: http://localhost:3000/d/$NEW_UID"
echo "🔄 Restart the Docker containers to apply the changes: just up"

exit 0 