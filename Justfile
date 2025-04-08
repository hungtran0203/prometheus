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
#   just open vault      - open Vault UI
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
    elif [ "{{dashboard}}" = "vault" ]; then \
        open http://localhost:8200/ui; \
    else \
        echo "Unknown dashboard: {{dashboard}}"; \
        echo "Available options: grafana, prometheus, logs, vector, vault"; \
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

# Fetch logs from Docker containers and sockets
# Usage: just docker-logs [container] [limit]
# Examples:
#   just docker-logs         - show all logs (both Docker and socket logs)
#   just docker-logs all     - show all logs
#   just docker-logs socket  - show only socket logs
#   just docker-logs vector 5 - show last 5 logs from vector container
docker-logs container="all" limit="10":
    @echo "Fetching logs from Docker containers and sockets..."
    @if [ "{{container}}" = "all" ]; then \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type=~"docker_logs|socket"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | .stream as $labels | .values[] | "\(.0) | \($labels.container_name // "socket") | \(.1)"'; \
    elif [ "{{container}}" = "socket" ]; then \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="socket"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | .stream as $labels | .values[] | "\(.0) | socket | \(.1)"'; \
    else \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="docker_logs",container_name="{{container}}"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | .stream as $labels | .values[] | "\(.0) | \($labels.container_name) | \(.1)"'; \
    fi

# Fetch detailed logs from Docker containers and sockets
# Usage: just docker-logs-detailed [container] [limit]
# Examples:
#   just docker-logs-detailed         - show all logs with labels
#   just docker-logs-detailed all     - show all logs with labels
#   just docker-logs-detailed socket  - show only socket logs with labels
#   just docker-logs-detailed vector 5 - show last 5 logs from vector container with labels
docker-logs-detailed container="all" limit="10":
    @echo "Fetching detailed logs from Docker containers and sockets..."
    @if [ "{{container}}" = "all" ]; then \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type=~"docker_logs|socket"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | "Container: \(.stream.container_name // "socket")\nSource: \(.stream.source_type)\nLabels: \(.stream | del(.container_name, .source_type) | tostring)\nLog entries:" as $header | ($header, (.values[] | "[\(.0)] \(.1)"), "---") | select(length > 0)'; \
    elif [ "{{container}}" = "socket" ]; then \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="socket"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | "Source: socket\nLabels: \(.stream | del(.source_type) | tostring)\nLog entries:" as $header | ($header, (.values[] | "[\(.0)] \(.1)"), "---") | select(length > 0)'; \
    else \
        curl -s "http://localhost:3100/loki/api/v1/query_range" \
            --data-urlencode 'query={source_type="docker_logs",container_name="{{container}}"}' \
            --data-urlencode 'start=1620000000000000000' \
            --data-urlencode 'end=1735689600000000000' \
            --data-urlencode 'limit={{limit}}' | \
        jq -r '.data.result[] | "Container: \(.stream.container_name)\nSource: docker_logs\nLabels: \(.stream | del(.container_name, .source_type) | tostring)\nLog entries:" as $header | ($header, (.values[] | "[\(.0)] \(.1)"), "---") | select(length > 0)'; \
    fi

# -------------------- Vault Commands --------------------

# Initialize Vault server (only required once after clean install)
vault-init:
    @echo "Initializing Vault server..."
    @docker exec -it vault vault operator init > ./vault/vault-keys.txt
    @echo "⚠️ IMPORTANT: Unseal keys and root token have been saved to ./vault/vault-keys.txt"
    @echo "⚠️ Keep this file safe and secure!"
    @echo "✅ Vault initialized!"

# Unseal Vault server (required after each restart)
vault-unseal:
    @echo "Unsealing Vault server..."
    @echo "Enter unseal key 1:"
    @read KEY && docker exec -it vault vault operator unseal $$KEY
    @echo "Enter unseal key 2:"
    @read KEY && docker exec -it vault vault operator unseal $$KEY
    @echo "Enter unseal key 3:"
    @read KEY && docker exec -it vault vault operator unseal $$KEY
    @echo "✅ Vault unsealed!"

# Set Vault token and authenticate
vault-login:
    @echo "Logging into Vault..."
    @echo "Enter root token:"
    @read TOKEN && docker exec -it vault vault login $$TOKEN
    @echo "✅ Logged in to Vault!"

# Create a new secret (key-value pair)
# Usage: just vault-create-secret path key value
# Example: just vault-create-secret secret/databases/postgres username db_user
vault-create-secret path key value:
    @echo "Creating secret {{key}} at {{path}}..."
    @docker exec -it vault vault kv put {{path}} {{key}}={{value}}
    @echo "✅ Secret created!"

# Get a secret
# Usage: just vault-get-secret path
# Example: just vault-get-secret secret/databases/postgres
vault-get-secret path:
    @echo "Getting secret at {{path}}..."
    @docker exec -it vault vault kv get {{path}}

# Enable the KV secrets engine v2 (only required once after init)
vault-enable-kv:
    @echo "Enabling KV secrets engine v2..."
    @docker exec -it vault vault secrets enable -path=secret kv-v2
    @echo "✅ KV secrets engine enabled!"

# Check Vault status
vault-status:
    @echo "Checking Vault status..."
    @docker exec -it vault vault status
