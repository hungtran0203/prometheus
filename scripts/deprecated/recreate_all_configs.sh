#!/bin/bash

# Script to recreate all configurations from templates
# Usage: ./scripts/recreate_all_configs.sh

echo "🔄 Recreating all configurations from templates..."

# Check if templates exist
missing_templates=()
[ ! -f "templates/app_exporter.yml.template" ] && missing_templates+=("app_exporter.yml.template")
[ ! -f "templates/nginx_server.conf.template" ] && missing_templates+=("nginx_server.conf.template")
[ ! -f "templates/prometheus_config.yml.template" ] && missing_templates+=("prometheus_config.yml.template")
[ ! -f "templates/grafana_dashboard.json.template" ] && missing_templates+=("grafana_dashboard.json.template")

if [ ${#missing_templates[@]} -gt 0 ]; then
    echo "⚠️ Warning: The following template files are missing:"
    for template in "${missing_templates[@]}"; do
        echo "  - $template"
    done
    echo "Some configurations may not be recreated."
    echo
fi

# 1. Recreate app exporter configurations
if [ -f "templates/app_exporter.yml.template" ]; then
    echo "🔄 Recreating app exporter configurations..."
    for app_file in docker-compose-app/*.yml; do
        if [ -f "$app_file" ]; then
            app_name=$(basename "$app_file" .yml)
            echo "  🔧 Processing $app_name..."
            
            # Extract port from the nginx configuration
            port=$(grep -o 'scrape-uri=http://dev-proxy:[0-9]*' "$app_file" | grep -o '[0-9]*')
            
            if [ -z "$port" ]; then
                echo "  ⚠️ Warning: Could not extract port for $app_name, skipping."
                continue
            fi
            
            # Use the template to recreate the configuration
            cat templates/app_exporter.yml.template | \
                sed "s/{{APP_NAME}}/$app_name/g" | \
                sed "s/{{PORT}}/$port/g" > "$app_file"
                
            echo "  ✅ Recreated app exporter configuration for $app_name"
        fi
    done
else
    echo "⚠️ Skipping app exporter configurations (template missing)"
fi

# 2. Recreate Nginx server configurations
if [ -f "templates/nginx_server.conf.template" ]; then
    echo "🔄 Recreating Nginx server configurations..."
    for server_file in nginx/servers/*.conf; do
        # Skip the main.conf file
        if [ "$(basename "$server_file")" == "main.conf" ]; then
            continue
        fi
        
        if [ -f "$server_file" ]; then
            app_name=$(basename "$server_file" .conf)
            echo "  🔧 Processing $app_name..."
            
            # Extract port and target port
            port=$(grep "listen" "$server_file" | head -1 | grep -o '[0-9]*')
            forward_port=$(grep "proxy_pass" "$server_file" | grep -o '[0-9]*' | tail -1)
            
            if [ -z "$port" ] || [ -z "$forward_port" ]; then
                echo "  ⚠️ Warning: Could not extract ports for $app_name, skipping."
                continue
            fi
            
            # Use the template to recreate the configuration
            cat templates/nginx_server.conf.template | \
                sed "s/{{APP_NAME}}/$app_name/g" | \
                sed "s/{{PORT}}/$port/g" | \
                sed "s/{{FORWARD_PORT}}/$forward_port/g" > "$server_file"
                
            echo "  ✅ Recreated Nginx server configuration for $app_name"
        fi
    done
else
    echo "⚠️ Skipping Nginx server configurations (template missing)"
fi

# 3. Recreate Prometheus configurations
if [ -f "templates/prometheus_config.yml.template" ]; then
    echo "🔄 Recreating Prometheus configurations..."
    for config_file in prometheus/conf.d/*.yml; do
        # Skip files that don't represent an app
        if [ "$(basename "$config_file")" == "test_apps.yml" ]; then
            continue
        fi
        
        if [ -f "$config_file" ]; then
            app_name=$(basename "$config_file" .yml)
            echo "  🔧 Processing $app_name..."
            
            # Extract port from the file
            port=$(grep -o "port: '[0-9]*'" "$config_file" | grep -o '[0-9]*')
            
            if [ -z "$port" ]; then
                echo "  ⚠️ Warning: Could not extract port for $app_name, skipping."
                continue
            fi
            
            # Use the template to recreate the configuration
            cat templates/prometheus_config.yml.template | \
                sed "s/{{APP_NAME}}/$app_name/g" | \
                sed "s/{{PORT}}/$port/g" > "$config_file"
                
            echo "  ✅ Recreated Prometheus configuration for $app_name"
        fi
    done
else
    echo "⚠️ Skipping Prometheus configurations (template missing)"
fi

# 4. Recreate Grafana dashboards
if [ -f "templates/grafana_dashboard.json.template" ]; then
    echo "🔄 Recreating Grafana dashboards..."
    for dashboard_file in grafana/provisioning/dashboards/*_app_metrics.json; do
        # Skip files that don't represent an app
        if [ "$(basename "$dashboard_file")" == "mac_system_app_metrics.json" ]; then
            continue
        fi
        
        if [ -f "$dashboard_file" ]; then
            app_name=$(basename "$dashboard_file" _app_metrics.json)
            app_name_caps=$(echo $app_name | sed 's/\b\(.\)/\u\1/g')  # Capitalize first letter
            echo "  🔧 Processing $app_name..."
            
            # Extract or generate UID
            existing_uid=$(grep -o '"uid": "[^"]*"' "$dashboard_file" | cut -d'"' -f4)
            if [ -z "$existing_uid" ]; then
                new_uid="${app_name}-$(date +%s | shasum | head -c 8)"
            else
                new_uid="$existing_uid"
            fi
            
            # Use the template to recreate the dashboard
            cat templates/grafana_dashboard.json.template | \
                sed "s/{{APP_NAME}}/$app_name/g" | \
                sed "s/{{APP_NAME_CAPS}}/$app_name_caps/g" | \
                sed "s/{{APP_UID}}/$new_uid/g" > "$dashboard_file"
                
            echo "  ✅ Recreated Grafana dashboard for $app_name_caps"
        fi
    done
else
    echo "⚠️ Skipping Grafana dashboards (template missing)"
fi

echo "🔄 All configurations have been recreated from templates."
echo "🔄 To apply changes:"
echo "  1. Run 'just update-compose-app' to update the docker-compose-app.yml file"
echo "  2. Run 'just restart' to restart all services with the new configurations"

exit 0 