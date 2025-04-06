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
if [ -f "templates/nginx_server.conf.template" ]; then
    # Create nginx server configuration from template
    cat templates/nginx_server.conf.template | \
        sed "s/{{APP_NAME}}/${APP_NAME}/g" | \
        sed "s/{{PORT}}/${PORT}/g" | \
        sed "s/{{FORWARD_PORT}}/${FORWARD_PORT}/g" > nginx/servers/${APP_NAME}.conf
    echo "✅ Created Nginx server configuration from template for ${APP_NAME}"
else
    # Fallback to direct creation if template doesn't exist
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
    echo "✅ Created Nginx server configuration for ${APP_NAME} (without template)"
fi

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

# 3. Create a dedicated docker-compose file for the app exporter
echo "🔧 Creating exporter service configuration..."

# Create docker-compose-app directory if it doesn't exist
mkdir -p docker-compose-app

# Use the template file to create the individual docker-compose file for this app
if [ -f "templates/app_exporter.yml.template" ]; then
    # Create the app exporter config from template
    cat templates/app_exporter.yml.template | \
        sed "s/{{APP_NAME}}/${APP_NAME}/g" | \
        sed "s/{{PORT}}/${PORT}/g" > docker-compose-app/${APP_NAME}.yml
    echo "✅ Created exporter service from template for ${APP_NAME}"
else
    # Fallback to direct creation if template doesn't exist
    cat > docker-compose-app/${APP_NAME}.yml << EOF
services:
  ${APP_NAME}-exporter:
    image: nginx/nginx-prometheus-exporter:0.11.0
    container_name: ${APP_NAME}-exporter
    restart: unless-stopped
    ports:
      - "4${PORT}:9113"
    command:
      - "--nginx.scrape-uri=http://dev-proxy:$PORT/${APP_NAME}_status"
      - "--prometheus.const-label=app=$APP_NAME"
      - "--prometheus.const-label=port=$PORT"
    networks:
      - monitoring_network
EOF
    echo "✅ Created exporter service configuration for ${APP_NAME} (without template)"
fi

# Check if the app is already included in the main docker-compose-app.yml
if ! grep -q "docker-compose-app/${APP_NAME}.yml" docker-compose-app.yml; then
    # Update the docker-compose-app.yml file using the helper script
    ./scripts/update_compose_app.sh
fi

echo "✅ Created exporter service configuration for ${APP_NAME}"

# 4. Create or update Prometheus config in conf.d directory
echo "🔧 Updating Prometheus configuration..."

if [ -f "templates/prometheus_config.yml.template" ]; then
    # Create Prometheus configuration from template
    cat templates/prometheus_config.yml.template | \
        sed "s/{{APP_NAME}}/${APP_NAME}/g" | \
        sed "s/{{PORT}}/${PORT}/g" > prometheus/conf.d/${APP_NAME}.yml
    echo "✅ Created Prometheus configuration from template for ${APP_NAME}"
else
    # Create the config file in conf.d (fallback)
    cat > prometheus/conf.d/${APP_NAME}.yml << EOF
- targets: ['${APP_NAME}-exporter:9113']
  labels:
    job: '${APP_NAME}_proxy'
    service: '${APP_NAME}-proxy'
    environment: 'development'
    app: '${APP_NAME}'
    port: '${PORT}'
EOF
    echo "✅ Created Prometheus configuration file for ${APP_NAME} (without template)"
fi

# 5. Create a dashboard from template
echo "🔧 Creating Grafana dashboard..."

if [ -f "templates/grafana_dashboard.json.template" ]; then
    # Create a new UID for the dashboard
    NEW_UID="${APP_NAME}-$(date +%s | shasum | head -c 8)"
    
    # Create dashboard from template
    cat templates/grafana_dashboard.json.template | \
        sed "s/{{APP_NAME}}/${APP_NAME}/g" | \
        sed "s/{{APP_NAME_CAPS}}/${APP_NAME_CAPS}/g" | \
        sed "s/{{APP_UID}}/${NEW_UID}/g" > grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
    
    echo "✅ Created Grafana dashboard from template for ${APP_NAME_CAPS}"
else
    # Fallback to copying and modifying an existing dashboard
    # Create the dashboard from the template
    cp grafana/provisioning/dashboards/nodejs_app_metrics.json grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

    # Update the dashboard with the app name
    perl -i -pe "s/Node.js/${APP_NAME_CAPS}/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
    perl -i -pe "s/nodejs/${APP_NAME}/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json

    # Update the dashboard ID and UID to avoid conflicts
    NEW_UID="${APP_NAME}-$(date +%s | shasum | head -c 8)"
    perl -i -pe "s/\"uid\":\s*\"[^\"]*\"/\"uid\": \"$NEW_UID\"/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
    perl -i -pe "s/\"id\":\s*\d+/\"id\": null/g" grafana/provisioning/dashboards/${APP_NAME}_app_metrics.json
    
    echo "✅ Created Grafana dashboard for ${APP_NAME_CAPS} (without template)"
fi

echo "✅ Monitoring has been set up for $APP_NAME_CAPS"
echo "🔍 Grafana dashboard will be available at: http://localhost:3000/d/$NEW_UID"
echo "🔄 Restart the Docker containers to apply the changes: just up"

exit 0 