#!/usr/bin/env bash
# Script to add monitoring for a new application
# Usage: ./add_monitoring.sh app_name port target_port

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 app_name port target_port"
  echo "Example: $0 myapp 3005 23005"
  exit 1
fi

APP_NAME="$1"
PORT="$2"
TARGET_PORT="$3"
APP_NAME_CAP=$(echo "$APP_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

echo "🔧 Setting up monitoring for $APP_NAME_CAP on port $PORT (forwarding to $TARGET_PORT)"

# 1. Create the Nginx configuration for the new app
echo "🔧 Adding Nginx configuration..."
cat > nginx_config.tmp << EOF
# Port forwarding for $APP_NAME app ($PORT -> $TARGET_PORT)
server {
    listen $PORT;
    server_name dev.local;
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;

    # Status endpoint for $APP_NAME app
    location = /${APP_NAME}_status {
        stub_status on;
        access_log off;
    }

    location / {
        proxy_pass http://host.docker.internal:$TARGET_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Find the last closing brace and insert our config before it
LAST_BRACE_LINE=$(grep -n "^}" nginx/nginx.conf | tail -1 | cut -d: -f1)
head -n $((LAST_BRACE_LINE-1)) nginx/nginx.conf > nginx/nginx.conf.new
cat nginx_config.tmp >> nginx/nginx.conf.new
tail -n +$((LAST_BRACE_LINE)) nginx/nginx.conf >> nginx/nginx.conf.new
mv nginx/nginx.conf.new nginx/nginx.conf
rm nginx_config.tmp

# 2. Update main docker-compose.yml with port mapping
echo "🔧 Updating docker-compose.yml with port mapping..."
# Use grep to find the line containing "# Main metrics port"
LINE_NUM=$(grep -n "# Main metrics port" docker-compose.yml | cut -d: -f1)
if [ -n "$LINE_NUM" ]; then
  head -n "$LINE_NUM" docker-compose.yml > docker-compose.yml.new
  echo "      - \"$PORT:$PORT\"    # $APP_NAME port" >> docker-compose.yml.new
  tail -n +$((LINE_NUM+1)) docker-compose.yml >> docker-compose.yml.new
  mv docker-compose.yml.new docker-compose.yml
else
  echo "⚠️ Could not find '# Main metrics port' in docker-compose.yml"
fi

# 3. Add exporter service to docker-compose.proxy-apps.yml
echo "🔧 Adding exporter service to docker-compose.proxy-apps.yml..."
cat > exporter_config.tmp << EOF

  # $APP_NAME app metrics exporter
  $APP_NAME-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: $APP_NAME-exporter
    ports:
      - "9$PORT:9113"  # Note: externally exposed on a different port
    command:
      - "--nginx.scrape-uri=http://nginx:$PORT/${APP_NAME}_status"
      - "--prometheus.const-label=app=$APP_NAME"
      - "--prometheus.const-label=port=$PORT"
    networks:
      - monitoring_network
    depends_on:
      - nginx
    restart: always
EOF

# Check if the file exists and create a backup
if [ -f docker-compose.proxy-apps.yml ]; then
  # Find closing brace of services section
  SERVICES_END=$(grep -n "^networks:" docker-compose.proxy-apps.yml | cut -d: -f1)
  if [ -n "$SERVICES_END" ]; then
    SERVICES_END=$((SERVICES_END-1))
    head -n $SERVICES_END docker-compose.proxy-apps.yml > docker-compose.proxy-apps.yml.new
    cat exporter_config.tmp >> docker-compose.proxy-apps.yml.new
    tail -n +$((SERVICES_END+1)) docker-compose.proxy-apps.yml >> docker-compose.proxy-apps.yml.new
    mv docker-compose.proxy-apps.yml.new docker-compose.proxy-apps.yml
  else
    echo "⚠️ Could not find services section end in docker-compose.proxy-apps.yml"
  fi
else
  echo "⚠️ docker-compose.proxy-apps.yml not found, creating new file"
  cat > docker-compose.proxy-apps.yml << EOF
version: '3'

services:$(<exporter_config.tmp)

networks:
  monitoring_network:
    external: true
    name: prometheus_monitoring_network
EOF
fi
rm exporter_config.tmp

# 4. Update prometheus.yml with the new job
echo "🔧 Updating Prometheus configuration..."
cat > prometheus_config.tmp << EOF

  # Specific metrics for the $APP_NAME application
  - job_name: "${APP_NAME}_proxy"
    scrape_interval: 5s
    static_configs:
      - targets: ["$APP_NAME-exporter:9113"]
        labels:
          service: "${APP_NAME}-proxy"
          environment: "development"
          app: "$APP_NAME"
          port: "$PORT"
EOF

# Find the line with "# Specific metrics for the Rust application" and add our config before it
LINE_NUM=$(grep -n "# Specific metrics for the Rust application" prometheus/prometheus.yml | cut -d: -f1)
if [ -n "$LINE_NUM" ]; then
  head -n $((LINE_NUM-1)) prometheus/prometheus.yml > prometheus/prometheus.yml.new
  cat prometheus_config.tmp >> prometheus/prometheus.yml.new
  tail -n +$LINE_NUM prometheus/prometheus.yml >> prometheus/prometheus.yml.new
  mv prometheus/prometheus.yml.new prometheus/prometheus.yml
else
  echo "⚠️ Could not find '# Specific metrics for the Rust application' in prometheus/prometheus.yml"
fi
rm prometheus_config.tmp

# 5. Create a dashboard from template (using rust_app_metrics.json as a template)
echo "🔧 Creating Grafana dashboard..."
cp grafana/provisioning/dashboards/rust_app_metrics.json grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

# Use perl for in-place substitution (works better on macOS)
perl -pi -e "s/Rust/$APP_NAME_CAP/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -pi -e "s/rust/$APP_NAME/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -pi -e "s/8000/$PORT/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -pi -e "s/38000/$TARGET_PORT/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
perl -pi -e "s/\"uid\": \".*\"/\"uid\": \"$APP_NAME-app-metrics\"/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

# 6. Update the status page - add to status endpoints list
echo "🔧 Updating status page..."
STATUS_ENDPOINT="<li><a href=\"/${APP_NAME}_status\">/${APP_NAME}_status</a> - $APP_NAME_CAP app (port $PORT)</li>"

# Find the section containing "Per-Application Status Endpoints" and add our entry before </ul>
SECTION_START=$(grep -n "Per-Application Status Endpoints" nginx/nginx.conf | cut -d: -f1)
if [ -n "$SECTION_START" ]; then
  # Find the closing </ul> tag after the section start
  UL_LINE=$(tail -n +$SECTION_START nginx/nginx.conf | grep -n "</ul>" | head -1 | cut -d: -f1)
  if [ -n "$UL_LINE" ]; then
    UL_LINE_ABS=$((SECTION_START + UL_LINE - 1))
    
    # Create modified file
    head -n $((UL_LINE_ABS-1)) nginx/nginx.conf > nginx/nginx.conf.new
    echo "                $STATUS_ENDPOINT" >> nginx/nginx.conf.new
    tail -n +$UL_LINE_ABS nginx/nginx.conf >> nginx/nginx.conf.new
    mv nginx/nginx.conf.new nginx/nginx.conf
  else
    echo "⚠️ Could not find closing </ul> for 'Per-Application Status Endpoints' in nginx/nginx.conf"
  fi
else
  echo "⚠️ Could not find 'Per-Application Status Endpoints' in nginx/nginx.conf"
fi

# Add to port forwarding list
PORT_FORWARD="<li><strong>$PORT → $TARGET_PORT</strong>: $APP_NAME_CAP</li>"

# Find the section containing "Port Forwarding" and add our entry before </ul>
SECTION_START=$(grep -n "Port Forwarding" nginx/nginx.conf | cut -d: -f1)
if [ -n "$SECTION_START" ]; then
  # Find the closing </ul> tag after the section start
  UL_LINE=$(tail -n +$SECTION_START nginx/nginx.conf | grep -n "</ul>" | head -1 | cut -d: -f1)
  if [ -n "$UL_LINE" ]; then
    UL_LINE_ABS=$((SECTION_START + UL_LINE - 1))
    
    # Create modified file
    head -n $((UL_LINE_ABS-1)) nginx/nginx.conf > nginx/nginx.conf.new
    echo "                $PORT_FORWARD" >> nginx/nginx.conf.new
    tail -n +$UL_LINE_ABS nginx/nginx.conf >> nginx/nginx.conf.new
    mv nginx/nginx.conf.new nginx/nginx.conf
  else
    echo "⚠️ Could not find closing </ul> for 'Port Forwarding' in nginx/nginx.conf"
  fi
else
  echo "⚠️ Could not find 'Port Forwarding' in nginx/nginx.conf"
fi

# Update default route string in status page
perl -pi -e "s/Rust\\)';/Rust) $PORT -> $TARGET_PORT ($APP_NAME_CAP)';/" nginx/nginx.conf

echo "✅ Done! Configuration files have been updated." 