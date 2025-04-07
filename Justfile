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

# Restart services
# Usage: just restart [service]
# Examples:
#   just restart        - restart all services
#   just restart nginx  - restart only nginx
#   just restart apps   - restart all app services
restart service="all":
    @if [ "{{service}}" = "all" ]; then \
        echo "Restarting all services..."; \
        docker compose restart; \
        docker compose -f docker-compose-app.yml down; \
        docker compose -f docker-compose-app.yml up -d --remove-orphans; \
    elif [ "{{service}}" = "apps" ]; then \
        echo "Restarting application services..."; \
        docker compose -f docker-compose-app.yml down; \
        docker compose -f docker-compose-app.yml up -d --remove-orphans; \
    else \
        echo "Restarting {{service}}..."; \
        docker compose restart {{service}}; \
    fi

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

# Open dashboards and UIs
# Usage: just open [dashboard]
# Examples:
#   just open grafana    - open Grafana UI
#   just open prometheus - open Prometheus UI
#   just open logs       - open Logs Explorer in Grafana
#   just open vector     - open Vector Logs Dashboard
open dashboard="grafana":
    @echo "Opening {{dashboard}} dashboard..."
    @if [ "{{dashboard}}" = "grafana" ]; then \
        open http://localhost:3333; \
    elif [ "{{dashboard}}" = "prometheus" ]; then \
        open http://localhost:9090; \
    elif [ "{{dashboard}}" = "logs" ]; then \
        open http://localhost:3333/explore?orgId=1&left=%7B%22datasource%22:%22Loki%22,%22queries%22:%5B%7B%22refId%22:%22A%22%7D%5D%7D; \
    elif [ "{{dashboard}}" = "vector" ]; then \
        open http://localhost:3333/d/vector-logs-dashboard/vector-logs-dashboard; \
    else \
        echo "Unknown dashboard: {{dashboard}}"; \
        echo "Available options: grafana, prometheus, logs, vector"; \
    fi

# Show active targets in Prometheus
show-targets:
    @echo "Fetching Prometheus targets..."
    curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {job: .labels.job, state: .health, target: .labels.instance}'

# Start/stop all services
start:
    @echo "Starting all services..."
    docker compose up -d
    docker compose -f docker-compose-app.yml up -d

stop:
    @echo "Stopping all services..."
    docker compose down
    docker compose -f docker-compose-app.yml down

# Watch and forward logs from a process listening on a specific port
# Usage: just forward-logs port
# Example: just forward-logs 3000
forward-logs port:
    @echo "Watching for process on port {{port}} and forwarding logs to Vector (port 45000)..."
    @./scripts/utils/forward_logs.sh {{port}}

# Get stdout and stderr from a process by PID
# Usage: just get-log pid
# Example: just get-log 83976
get-log pid:
    @echo "Fetching stdout and stderr from process {{pid}}..."
    @./scripts/utils/get_process_logs.sh {{pid}}

# View logs from Docker containers and socket logs in Loki
# Usage: just docker-logs [container_name] [limit]
# Examples:
#   just docker-logs        - show logs from all containers and sockets
#   just docker-logs loki   - show logs from the loki container
#   just docker-logs socket - show logs from socket connections
#   just docker-logs loki 50 - show 50 logs from the loki container
docker-logs container="all" limit="20":
    @echo "Fetching logs from Docker containers and sockets..."
    @if [ "{{container}}" = "all" ]; then \
        curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type=~"docker_logs|socket"}' \
            --data-urlencode "limit={{limit}}" \
            --data-urlencode "start=$(date -u -v-10M +%s)000000000" \
            --data-urlencode "end=$(date -u +%s)000000000" | \
            jq -r '.data.result[] | .values[] | .[0] + " | " + (.[1] | fromjson | .message)' 2>/dev/null || \
            echo "No logs found"; \
    elif [ "{{container}}" = "socket" ]; then \
        curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="socket"}' \
            --data-urlencode "limit={{limit}}" \
            --data-urlencode "start=$(date -u -v-10M +%s)000000000" \
            --data-urlencode "end=$(date -u +%s)000000000" | \
            jq -r '.data.result[] | .values[] | .[0] + " | " + (.[1] | fromjson | .message)' 2>/dev/null || \
            echo "No socket logs found"; \
    else \
        curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="docker_logs", container_name="{{container}}"}' \
            --data-urlencode "limit={{limit}}" \
            --data-urlencode "start=$(date -u -v-10M +%s)000000000" \
            --data-urlencode "end=$(date -u +%s)000000000" | \
            jq -r '.data.result[] | .values[] | .[0] + " | " + (.[1] | fromjson | .message)' 2>/dev/null || \
            echo "No logs found for container {{container}}"; \
    fi
