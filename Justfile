# Proxy App Monitoring - Task Runner
# Run commands with: just <command>

# Default recipe to display help information
default:
    @just --list

# Add monitoring for a new application
# Usage: just add-app app_name port target_port
# Example: just add-app newapp 3005 33005
add-app app_name port target_port:
    @echo "Adding monitoring for {{app_name}} on port {{port}} (forwarding to {{target_port}})"
    @./scripts/add_monitoring.sh "{{app_name}}" "{{port}}" "{{target_port}}"
    @echo "✅ Configuration updated! Run 'just restart' to apply changes."

# Remove monitoring for an application
# Usage: just remove-app app_name port
# Example: just remove-app newapp 3005
remove-app app_name port:
    @echo "Removing monitoring for {{app_name}} on port {{port}}"
    @./scripts/remove_monitoring.sh "{{app_name}}" "{{port}}"
    @echo "✅ Configuration updated! Run 'just restart' to apply changes."

# List all currently monitored applications
list-apps:
    @./scripts/list_apps.sh

# Restart all services to apply changes
restart:
    @echo "Restarting services..."
    docker compose restart
    docker compose -f docker-compose-app.yml down
    docker compose -f docker-compose-app.yml up -d --remove-orphans

# Restart only Nginx to apply configuration changes
restart-nginx:
    @echo "Restarting Nginx..."
    docker compose restart nginx

# Restart only Grafana to apply dashboard changes
restart-grafana:
    @echo "Restarting Grafana..."
    docker compose restart grafana

# Restart only Prometheus to apply configuration changes
restart-prometheus:
    @echo "Restarting Prometheus..."
    docker compose restart prometheus

# Restart only proxy app services
restart-proxy-apps:
    @echo "Restarting proxy app services..."
    docker compose -f docker-compose-app.yml restart

# Update and restart all proxy app services
update-restart-proxy-apps:
    @echo "Updating docker-compose-app.yml and restarting all proxy app services..."
    @./scripts/update_compose_app.sh
    docker compose -f docker-compose-app.yml down
    docker compose -f docker-compose-app.yml up -d --remove-orphans

# Recreate all app exporter configurations using the template
recreate-app-exporters:
    @./scripts/recreate_app_exporters.sh

# Recreate all configurations from templates
recreate-all-configs:
    @./scripts/recreate_all_configs.sh

# Check the status of all services
status:
    @echo "Checking service status..."
    docker compose ps
    @echo "\nProxy app services:"
    docker compose -f docker-compose-app.yml ps

# View logs for a specific service
# Usage: just logs service [tail_lines]
# Example: just logs nginx 50
logs service tail_lines="20":
    docker compose logs {{service}} --tail {{tail_lines}} -f

# Open the Grafana UI in the default browser
open-grafana:
    @echo "Opening Grafana UI..."
    open http://localhost:3333

# Open the Prometheus UI in the default browser
open-prometheus:
    @echo "Opening Prometheus UI..."
    open http://localhost:9090

# Open the Nginx status page in the default browser
open-status:
    @echo "Opening Nginx status page..."
    open http://localhost:8686/status

# Show active targets in Prometheus
show-targets:
    @echo "Fetching Prometheus targets..."
    curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {job: .labels.job, state: .health, target: .labels.instance}'

# Show metrics for a specific app
# Usage: just show-metrics app_name
# Example: just show-metrics nodejs
show-metrics app_name:
    @echo "Fetching metrics for {{app_name}}..."
    curl -s "http://localhost:9090/api/v1/query?query=nginx_http_requests_total" | jq '.data.result[] | select(.metric.app == "{{app_name}}")'

# Start all services
start:
    @echo "Starting all services..."
    docker compose up -d
    docker compose -f docker-compose-app.yml up -d

# Stop all services
stop:
    @echo "Stopping all services..."
    docker compose down
    docker compose -f docker-compose-app.yml down

# Update the docker-compose-app.yml file
update-compose-app:
    @echo "Updating docker-compose-app.yml..."
    @./scripts/update_compose_app.sh

# Generate Vector configuration for log collection
generate-vector-config:
    @echo "Generating Vector configuration for log collection..."
    @./scripts/generate_vector_config.sh

# View logs for a specific app using Loki Query
# Usage: just app-logs app_name [lines]
# Example: just app-logs nodejs 50
app-logs app_name lines="100":
    @echo "Querying logs for {{app_name}}..."
    curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
      --data-urlencode "query={app=\"{{app_name}}\"}" \
      --data-urlencode "limit={{lines}}" \
      --data-urlencode "start=$(date -u -v-1d +%s)000000000" \
      --data-urlencode "end=$(date -u +%s)000000000" \
      | jq '.data.result[0].values[] | .[1]' -r

# Update compose files and restart services with log monitoring
update-with-logs:
    @echo "Updating configurations and restarting with log monitoring..."
    @./scripts/generate_vector_config.sh
    @./scripts/update_compose_app.sh
    docker compose restart loki vector
    docker compose -f docker-compose-app.yml down
    docker compose -f docker-compose-app.yml up -d

# Open the Loki logs viewer in Grafana
open-logs:
    @echo "Opening Logs Explorer in Grafana..."
    open http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22%7D%5D%7D

# Setup log monitoring with Vector and Loki
setup-logs:
    @echo "Setting up log monitoring with Vector and Loki..."
    @echo "1. Generating Vector configuration..."
    @./scripts/generate_vector_config.sh
    @echo "2. Creating directories..."
    @mkdir -p grafana/provisioning/datasources loki/data vector
    @echo "3. Starting Loki and Vector services..."
    docker compose up -d loki vector
    @echo "4. Waiting for Loki to start..."
    @sleep 5
    @echo "5. Testing Loki connection..."
    curl -s http://localhost:3100/ready || echo "⚠️ Loki is not ready yet. It might take a minute to fully start."
    @echo "\n✅ Log monitoring setup complete! View logs at http://localhost:3333/explore"
    @echo "Try 'just open-logs' to open the Grafana logs view"
