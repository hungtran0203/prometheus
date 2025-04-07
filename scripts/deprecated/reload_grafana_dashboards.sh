#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}====================================${NC}"
echo -e "${YELLOW}   Grafana Dashboard Reload Tool    ${NC}"
echo -e "${YELLOW}====================================${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl to use this script.${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Some features may not work correctly.${NC}"
    echo -e "${YELLOW}Consider installing jq for better functionality:${NC}"
    echo -e "  brew install jq (Mac) or apt install jq (Linux)${NC}"
fi

# Grafana details
GRAFANA_URL="http://localhost:3333"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
PROMETHEUS_URL="http://localhost:9090"

# Check if Grafana is running
echo -e "\n${YELLOW}Checking if Grafana is running...${NC}"
if ! curl -s --head "${GRAFANA_URL}" > /dev/null; then
    echo -e "${RED}Error: Grafana is not running at ${GRAFANA_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
    exit 1
fi
echo -e "${GREEN}Grafana is running!${NC}"

# Function to reload Prometheus
reload_prometheus() {
    echo -e "\n${YELLOW}Reloading Prometheus configuration...${NC}"
    RELOAD_RESULT=$(curl -s -X POST "${PROMETHEUS_URL}/-/reload" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully requested Prometheus configuration reload.${NC}"
    else
        echo -e "${RED}Failed to reload Prometheus configuration: ${RELOAD_RESULT}${NC}"
        echo -e "${YELLOW}Note: This is normal if Prometheus was not started with --web.enable-lifecycle flag.${NC}"
    fi
}

# Function to restart Grafana using Docker
restart_grafana_container() {
    echo -e "\n${YELLOW}Restarting Grafana container...${NC}"
    DOCKER_RESULT=$(docker restart grafana 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Grafana container restarted successfully!${NC}"
        echo -e "${YELLOW}Waiting for Grafana to become available again...${NC}"
        
        # Wait for Grafana to become available
        for i in {1..30}; do
            if curl -s --head "${GRAFANA_URL}" > /dev/null; then
                echo -e "${GREEN}Grafana is back online!${NC}"
                return 0
            fi
            echo -n "."
            sleep 1
        done
        
        echo -e "\n${RED}Timed out waiting for Grafana to restart.${NC}"
        return 1
    else
        echo -e "${RED}Failed to restart Grafana container: ${DOCKER_RESULT}${NC}"
        echo -e "${YELLOW}You might need to run this script with sudo or have Docker permissions.${NC}"
        return 1
    fi
}

# Function to reload Grafana dashboards using API
reload_grafana_dashboards() {
    echo -e "\n${YELLOW}Forcing Grafana to reload dashboards from disk...${NC}"
    
    # 1. Authenticate and get token
    echo -e "${YELLOW}Authenticating with Grafana...${NC}"
    
    TOKEN_RESP=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"user\":\"${GRAFANA_USER}\",\"password\":\"${GRAFANA_PASSWORD}\"}" ${GRAFANA_URL}/api/auth/login)
    
    if command -v jq &> /dev/null; then
        TOKEN=$(echo $TOKEN_RESP | jq -r '.key')
    else
        # Fallback if jq is not available
        TOKEN=$(echo $TOKEN_RESP | grep -o '"key":"[^"]*' | sed 's/"key":"//')
    fi
    
    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        echo -e "${RED}Failed to authenticate with Grafana API.${NC}"
        echo -e "${YELLOW}Using container restart method instead...${NC}"
        restart_grafana_container
        return
    fi
    
    # 2. Reload dashboard provisioning
    echo -e "${YELLOW}Reloading dashboard provisioning...${NC}"
    RELOAD_RESP=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" ${GRAFANA_URL}/api/admin/provisioning/dashboards/reload)
    
    if [[ "$RELOAD_RESP" == *"Dashboards config reloaded"* ]]; then
        echo -e "${GREEN}Dashboards successfully reloaded via API!${NC}"
    else
        echo -e "${RED}Failed to reload dashboards via API: ${RELOAD_RESP}${NC}"
        echo -e "${YELLOW}Using container restart method as fallback...${NC}"
        restart_grafana_container
    fi
}

# Main program
reload_prometheus
reload_grafana_dashboards

echo -e "\n${GREEN}Dashboard reload process completed!${NC}"
echo -e "${YELLOW}Access your Grafana dashboards at:${NC}"
echo -e "  ${GRAFANA_URL} (login with admin/admin)${NC}\n"
echo -e "${YELLOW}Available dashboards:${NC}"
echo -e "  • Node.js Proxy Metrics"
echo -e "  • Next.js App Metrics"
echo -e "  • Remix App Metrics"
echo -e "  • React App Metrics"
echo -e "  • Rust App Metrics"
echo -e "  • Nginx Proxy Metrics"

exit 0 