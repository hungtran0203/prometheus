#!/bin/bash

# Configuration
GRAFANA_URL="http://localhost:3333"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${YELLOW}====================================${NC}"
echo -e "${YELLOW}   Grafana Dashboard Reload Tool    ${NC}"
echo -e "${YELLOW}====================================${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl to use this script.${NC}"
    exit 1
fi

# Check if Grafana is running
echo -e "\n${YELLOW}Checking if Grafana is running...${NC}"
if ! curl -s --head "${GRAFANA_URL}" > /dev/null; then
    echo -e "${RED}Error: Grafana is not running at ${GRAFANA_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker-compose up -d"
    exit 1
fi

echo -e "${GREEN}Grafana is running!${NC}"

# Function to reload dashboards
reload_dashboards() {
    echo -e "\n${YELLOW}Reloading Grafana dashboards...${NC}"
    
    # Reload dashboard provisioning
    RESPONSE=$(curl -s -X POST -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        "${GRAFANA_URL}/api/admin/provisioning/dashboards/reload" -w "\n%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" == 2* ]]; then
        echo -e "${GREEN}Success: Dashboards provisioning reloaded!${NC}"
    else
        echo -e "${RED}Error: Failed to reload dashboard provisioning.${NC}"
        echo -e "${RED}HTTP Status: ${HTTP_CODE}${NC}"
        echo -e "${RED}Response: ${RESPONSE_BODY}${NC}"
        return 1
    fi
    
    return 0
}

# Reload dashboards
if reload_dashboards; then
    echo -e "\n${GREEN}Your dashboards have been reloaded!${NC}"
    echo -e "${YELLOW}You can access Grafana at:${NC} ${GRAFANA_URL}"
    echo -e "${YELLOW}Login with:${NC} ${GRAFANA_USER}/${GRAFANA_PASSWORD}"
else
    echo -e "\n${RED}Failed to reload dashboards.${NC}"
    exit 1
fi

exit 0 