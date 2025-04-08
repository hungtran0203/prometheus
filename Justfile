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
        docker compose -f docker-compose-hcl.yml down; \
        docker compose -f docker-compose-hcl.yml up -d --remove-orphans; \
    elif [ "{{service}}" = "apps" ]; then \
        echo "Restarting application services..."; \
        docker compose -f docker-compose-app.yml down; \
        docker compose -f docker-compose-app.yml up -d --remove-orphans; \
    elif [ "{{service}}" = "hashicorp" ]; then \
        echo "Restarting HashiCorp services..."; \
        docker compose -f docker-compose-hcl.yml down; \
        docker compose -f docker-compose-hcl.yml up -d --remove-orphans; \
    fi

# Check the status of all services
status:
    @echo "Checking service status..."
    docker compose ps
    @echo "\nProxy app services:"
    docker compose -f docker-compose-app.yml ps
    @echo "\nHashiCorp services:"
    docker compose -f docker-compose-hcl.yml ps

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

# -------------------- Local Nomad Commands --------------------

# Start Nomad on the host
start-nomad:
    @echo "Creating local data directory..."
    @mkdir -p ./nomad/data
    @echo "Starting Nomad on the host..."
    @echo "Stopping any existing container Nomad instance first..."
    @docker stop hc-nomad 2>/dev/null || true
    @echo "Starting local Nomad agent..."
    @nohup nomad agent -config=./nomad/config/local/nomad.hcl -dev > ./nomad/logs/nomad.log 2>&1 & echo $$! > ./nomad/logs/nomad.pid
    @echo "✅ Nomad is now running locally in the background (PID: $$(cat ./nomad/logs/nomad.pid))"
    @echo "Access the UI at http://localhost:4646"

# Stop local Nomad
stop-nomad:
    @echo "Stopping local Nomad agent..."
    @if [ -f ./nomad/logs/nomad.pid ]; then \
        PID=$$(cat ./nomad/logs/nomad.pid); \
        if ps -p $$PID > /dev/null; then \
            kill $$PID; \
            echo "Nomad process (PID: $$PID) stopped."; \
        else \
            echo "Nomad process (PID: $$PID) not found, it may have already stopped."; \
        fi; \
        rm -f ./nomad/logs/nomad.pid; \
    else \
        echo "No PID file found, trying to find and kill Nomad process..."; \
        pkill -f "nomad agent" || echo "No Nomad process found"; \
    fi
    @echo "✅ Local Nomad stopped"

# Run a Nomad job with the local Nomad instance
# Usage: just nomad-job-run job_file
# Example: just nomad-job-run ./nomad/jobs/vault-example.hcl
nomad-job-run job_file:
    @echo "Running Nomad job from {{job_file}} using local Nomad..."
    @nomad job run {{job_file}}
    @echo "✅ Job submitted to local Nomad!"

# Stop a Nomad job with the local Nomad instance
# Usage: just nomad-job-stop job_name
# Example: just nomad-job-stop vault-example
nomad-job-stop job_name:
    @echo "Stopping Nomad job {{job_name}} using local Nomad..."
    @nomad job stop {{job_name}}
    @echo "✅ Job stopped!"

# Check status of local Nomad jobs
nomad-status:
    @echo "Checking status of jobs in local Nomad..."
    @nomad job status
    @echo "For more details on a specific job: nomad job status JOB_NAME"

# -------------------- End Local Nomad Commands -------------------- 

# -------------------- DNS Configuration Commands --------------------

# Configure dnsmasq to forward .consul queries to Consul and other queries to 8.8.8.8
# Usage: just start-dns
# Example: just start-dns
start-dns consul_port="8601":
    @cp /tmp/dns-config/dnsmasq.conf /usr/local/etc/dnsmasq.conf
    @echo "Restarting dnsmasq service..."
    @brew services restart dnsmasq
