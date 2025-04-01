# Prometheus Monitoring Stack

This repository contains a Docker Compose setup for a complete monitoring stack using:

- Prometheus (metrics collection and storage)
- Grafana (visualization and dashboards)
- PostgreSQL Exporter (for PostgreSQL metrics)
- Node Exporter (for MacOS system metrics)

## Setup Instructions

### Prerequisites

- Docker and Docker Compose
- PostgreSQL (if using the postgres-exporter)
- MacOS with M-series chip (for node_exporter.sh)

### Quick Start

1. Start the monitoring stack:
   ```
   docker-compose up -d
   ```

2. Access the services:
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (credentials: admin/admin)

### MacOS Metrics Collection

To collect metrics from your MacOS host:

1. Run the node exporter script:
   ```
   ./exporters/node_exporter.sh
   ```

2. Prometheus is already configured to scrape these metrics via the `node_exporter_mac` job.

### PostgreSQL Connection

The PostgreSQL exporter is configured to connect to a PostgreSQL instance running on your host machine at `host.docker.internal:5432`. Update the connection string in docker-compose.yml if your setup differs.

## Included Dashboards

- PostgreSQL Connections - Shows active and total connections 