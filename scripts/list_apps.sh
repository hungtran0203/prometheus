#!/bin/bash

# Script to list all monitored applications
# Usage: ./scripts/list_apps.sh

# Disable error stop to prevent script from terminating on commands that fail
set +e
echo "🔍 Currently monitored applications:"
echo "======================================="

# First check if required files exist
NGINX_CONF="nginx/nginx.conf"
SERVERS_DIR="nginx/servers"
DOCKER_COMPOSE="docker-compose.yml"
PROMETHEUS_CONF_DIR="prometheus/conf.d"
GRAFANA_DASHBOARDS="grafana/provisioning/dashboards"

# Initialize missing files list
missing_files=""
[[ ! -f "$NGINX_CONF" ]] && missing_files="$missing_files $NGINX_CONF"
[[ ! -d "$SERVERS_DIR" ]] && missing_files="$missing_files $SERVERS_DIR"
[[ ! -f "$DOCKER_COMPOSE" ]] && missing_files="$missing_files $DOCKER_COMPOSE"
[[ ! -d "$PROMETHEUS_CONF_DIR" ]] && missing_files="$missing_files $PROMETHEUS_CONF_DIR"
[[ ! -d "$GRAFANA_DASHBOARDS" ]] && missing_files="$missing_files $GRAFANA_DASHBOARDS"

if [[ -n "$missing_files" ]]; then
    echo "⚠️ Warning: The following files/directories are missing:$missing_files"
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
    # Use ls instead of find to avoid issues
    server_files=$(ls -1 "$SERVERS_DIR"/*.conf 2>/dev/null || echo "")
    if [[ -n "$server_files" ]]; then
        echo "$server_files" | while read -r server_file; do
            # Skip if file doesn't exist or is main.conf
            if [[ ! -f "$server_file" || "$(basename "$server_file")" == "main.conf" ]]; then
                continue
            fi
            
            # Get app name from the conf file name
            app_name=$(basename "$server_file" .conf)
            # Get port from the file
            port=$(grep "listen" "$server_file" 2>/dev/null | head -1 | grep -o '[0-9]*' 2>/dev/null | head -1 || echo "unknown")
            # Find target port
            target_port=$(grep "proxy_pass" "$server_file" 2>/dev/null | head -1 | grep -o '[0-9]*' 2>/dev/null | head -1 || echo "unknown")
            
            if [[ -n "$app_name" ]]; then
                echo "  - $app_name (Port: $port → $target_port)"
                nginx_apps_found=1
            fi
        done
    else
        echo "  No .conf files found in $SERVERS_DIR"
    fi
else
    echo "  ⚠️ Nginx servers directory not found."
fi
check_apps_found $nginx_apps_found "applications"

# Check exporters in docker-compose-app.yml
echo
echo "📊 Exporter services in docker-compose-app.yml:"
exporter_found=0

if [[ -f "docker-compose-app.yml" ]]; then
    # Check if there are any app configs included
    app_configs=$(grep -o "docker-compose-app/.*\.yml" docker-compose-app.yml 2>/dev/null || echo "")
    if [[ -n "$app_configs" ]]; then
        echo "$app_configs" | while read -r config; do
            if [[ -n "$config" && -f "$config" ]]; then
                app_name=$(basename "$config" .yml)
                echo "  - $app_name-exporter"
                exporter_found=1
            fi
        done
    else
        echo "  No app configs found in docker-compose-app.yml"
    fi
else
    echo "  ⚠️ docker-compose-app.yml file not found."
fi

# Check for docker-compose.yml exporters
if [[ -f "$DOCKER_COMPOSE" ]]; then
    exporter_blocks=$(grep -n "# .* app metrics exporter" "$DOCKER_COMPOSE" 2>/dev/null || echo "")
    if [[ -n "$exporter_blocks" ]]; then
        echo "$exporter_blocks" | while read -r line; do
            if [[ -n "$line" ]]; then
                exporter_line=$(echo "$line" | cut -d':' -f2- 2>/dev/null || echo "")
                app=$(echo "$exporter_line" | sed 's/# \(.*\) app metrics exporter/\1/' 2>/dev/null || echo "")
                if [[ -n "$app" ]]; then
                    echo "  - $app-exporter"
                    exporter_found=1
                fi
            fi
        done
    fi
fi
check_apps_found $exporter_found "exporters"

# Check prometheus configs in conf.d directory
echo
echo "📊 Prometheus job configurations:"
prometheus_jobs_found=0
if [[ -d "$PROMETHEUS_CONF_DIR" ]]; then
    # Use ls instead of find
    config_files=$(ls -1 "$PROMETHEUS_CONF_DIR"/*.yml 2>/dev/null || echo "")
    if [[ -n "$config_files" ]]; then
        echo "$config_files" | while read -r config_file; do
            if [[ ! -f "$config_file" ]]; then
                continue
            fi
            
            app_name=$(basename "$config_file" .yml)
            # Skip files that don't represent an app
            if [[ "$app_name" == "test_apps" ]]; then
                # For test_apps.yml, extract individual app labels
                apps=$(grep -o "job: '[^']*'" "$config_file" 2>/dev/null | sed "s/job: '//;s/_proxy'//;s/'//g" 2>/dev/null | sort | uniq || echo "")
                if [[ -n "$apps" ]]; then
                    echo "$apps" | while read -r app; do
                        if [[ -n "$app" ]]; then
                            echo "  - $app"
                            prometheus_jobs_found=1
                        fi
                    done
                fi
            else
                # For regular app config files
                echo "  - $app_name"
                prometheus_jobs_found=1
            fi
        done
    else
        echo "  No .yml files found in $PROMETHEUS_CONF_DIR"
    fi
else
    echo "  ⚠️ Prometheus conf.d directory not found."
fi
check_apps_found $prometheus_jobs_found "jobs"

# Check Grafana dashboards
echo
echo "📊 Grafana dashboards:"
dashboard_found=0
if [[ -d "$GRAFANA_DASHBOARDS" ]]; then
    # Use ls instead of find
    dashboard_files=$(ls -1 "$GRAFANA_DASHBOARDS"/*_app_metrics.json 2>/dev/null || echo "")
    if [[ -n "$dashboard_files" ]]; then
        echo "$dashboard_files" | while read -r file; do
            if [[ ! -f "$file" ]]; then
                continue
            fi
            
            app=$(basename "$file" | sed 's/_app_metrics.json//' 2>/dev/null || echo "")
            if [[ "$app" != "mac_system" && -n "$app" ]]; then
                echo "  - $app"
                dashboard_found=1
            fi
        done
    else
        echo "  No dashboard files found in $GRAFANA_DASHBOARDS"
    fi
else
    echo "  ⚠️ Grafana dashboards directory not found."
fi
check_apps_found $dashboard_found "dashboards"

# Check for active containers 
echo
echo "📊 Currently running containers:"
if command -v docker &> /dev/null; then
    docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || echo "  ⚠️ Docker Compose command failed."
    echo
    echo "📊 Proxy app containers:"
    docker compose -f docker-compose-app.yml ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || echo "  ⚠️ Docker Compose command failed."
else
    echo "  ⚠️ Docker command not found. Is Docker installed?"
fi

echo
echo "💡 To add a new app, run: just add-app app_name port target_port"
echo "💡 To remove an app, run: just remove-app app_name port"

exit 0 