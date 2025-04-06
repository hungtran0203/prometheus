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
    #!/usr/bin/env bash
    set -eo pipefail
    echo "🔍 Currently monitored applications:"
    echo "======================================="
    
    # First check if required files exist
    NGINX_CONF="nginx/nginx.conf"
    SERVERS_DIR="nginx/servers"
    DOCKER_COMPOSE="docker-compose.yml"
    PROMETHEUS_YML="prometheus/prometheus.yml"
    GRAFANA_DASHBOARDS="grafana/provisioning/dashboards"
    
    missing_files=()
    [[ ! -f "$NGINX_CONF" ]] && missing_files+=("$NGINX_CONF")
    [[ ! -d "$SERVERS_DIR" ]] && missing_files+=("$SERVERS_DIR")
    [[ ! -f "$DOCKER_COMPOSE" ]] && missing_files+=("$DOCKER_COMPOSE")
    [[ ! -f "$PROMETHEUS_YML" ]] && missing_files+=("$PROMETHEUS_YML")
    [[ ! -d "$GRAFANA_DASHBOARDS" ]] && missing_files+=("$GRAFANA_DASHBOARDS")
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo "⚠️ Warning: The following files/directories are missing:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo "Some information may be incomplete."
        echo
    fi
    
    # Function to check if app found
    check_apps_found() {
        local found=$1
        local section=$2
        if [[ $found -eq 0 ]]; then
            echo "  No $section found."
        fi
    }
    
    # Check for app configurations in nginx/servers directory
    echo "📊 Apps in Nginx configuration:"
    nginx_apps_found=0
    if [[ -d "$SERVERS_DIR" ]]; then
        for server_file in "$SERVERS_DIR"/*.conf; do
            # Skip the main.conf file
            if [[ "$(basename "$server_file")" == "main.conf" ]]; then
                continue
            fi
            
            if [[ -f "$server_file" ]]; then
                # Get app name from the conf file name
                app_name=$(basename "$server_file" .conf)
                # Get port from the file
                port=$(grep "listen" "$server_file" | head -1 | grep -o '[0-9]*' | head -1)
                # Find target port
                target_port=$(grep "proxy_pass" "$server_file" | head -1 | grep -o '[0-9]*' | head -1)
                
                if [[ -n "$app_name" && -n "$port" ]]; then
                    echo "  - $app_name (Port: $port → $target_port)"
                    nginx_apps_found=1
                fi
            fi
        done
    else
        echo "  ⚠️ Nginx servers directory not found."
    fi
    check_apps_found $nginx_apps_found "applications"
    
    # Check exporters in docker-compose.yml
    echo
    echo "📊 Exporter services in docker-compose.yml:"
    exporter_found=0
    if [[ -f "$DOCKER_COMPOSE" ]]; then
        exporter_blocks=$(grep -n "# .* app metrics exporter" "$DOCKER_COMPOSE" 2>/dev/null || echo "")
        if [[ -n "$exporter_blocks" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    exporter_line=$(echo "$line" | cut -d':' -f2-)
                    app=$(echo "$exporter_line" | sed 's/# \(.*\) app metrics exporter/\1/')
                    if [[ -n "$app" ]]; then
                        echo "  - $app-exporter"
                        exporter_found=1
                    fi
                fi
            done <<< "$exporter_blocks"
        fi
    else
        echo "  ⚠️ Docker Compose file not found."
    fi
    check_apps_found $exporter_found "exporters"
    
    # Check prometheus targets
    echo
    echo "📊 Prometheus job configurations:"
    prometheus_jobs_found=0
    if [[ -f "$PROMETHEUS_YML" ]]; then
        job_blocks=$(grep -n "job_name: \".*_proxy\"" "$PROMETHEUS_YML" 2>/dev/null || echo "")
        if [[ -n "$job_blocks" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    job_line=$(echo "$line" | cut -d':' -f2-)
                    job=$(echo "$job_line" | sed 's/.*job_name: "\(.*\)".*/\1/')
                    if [[ -n "$job" ]]; then
                        echo "  - $job"
                        prometheus_jobs_found=1
                    fi
                fi
            done <<< "$job_blocks"
        fi
    else
        echo "  ⚠️ Prometheus configuration file not found."
    fi
    check_apps_found $prometheus_jobs_found "jobs"
    
    # Check Grafana dashboards
    echo
    echo "📊 Grafana dashboards:"
    dashboard_found=0
    if [[ -d "$GRAFANA_DASHBOARDS" ]]; then
        for file in "$GRAFANA_DASHBOARDS"/*_app_metrics.json; do
            if [[ -f "$file" ]]; then
                app=$(basename "$file" | sed 's/_app_metrics.json//')
                if [[ "$app" != "mac_system" && -n "$app" ]]; then
                    echo "  - $app"
                    dashboard_found=1
                fi
            fi
        done
    else
        echo "  ⚠️ Grafana dashboards directory not found."
    fi
    check_apps_found $dashboard_found "dashboards"
    
    # Check for active containers 
    echo
    echo "📊 Currently running containers:"
    docker compose ps 2>/dev/null || echo "  ⚠️ Docker Compose command failed. Is Docker running?"
    
    echo
    echo "💡 To add a new app, run: just add-app app_name port target_port"
    echo "💡 To remove an app, run: just remove-app app_name port"

# Restart all services to apply changes
restart:
    @echo "Restarting services..."
    docker compose restart
    docker compose -f docker-compose.proxy-apps.yml restart

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
    docker compose -f docker-compose.proxy-apps.yml restart

# Check the status of all services
status:
    @echo "Checking service status..."
    docker compose ps
    @echo "\nProxy app services:"
    docker compose -f docker-compose.proxy-apps.yml ps

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
    docker compose -f docker-compose.proxy-apps.yml up -d

# Stop all services
stop:
    @echo "Stopping all services..."
    docker compose down
    docker compose -f docker-compose.proxy-apps.yml down
