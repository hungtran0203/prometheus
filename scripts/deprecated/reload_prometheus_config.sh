#!/bin/bash

# Configuration
PROMETHEUS_URL="http://localhost:9090"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${YELLOW}====================================${NC}"
echo -e "${YELLOW}   Prometheus Config Reload Tool     ${NC}"
echo -e "${YELLOW}====================================${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl to use this script.${NC}"
    exit 1
fi

# Check if Prometheus is running
echo -e "\n${YELLOW}Checking if Prometheus is running...${NC}"
if ! curl -s --head "${PROMETHEUS_URL}" > /dev/null; then
    echo -e "${RED}Error: Prometheus is not running at ${PROMETHEUS_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}Prometheus is running!${NC}"

# Function to reload Prometheus configuration
reload_config() {
    echo -e "\n${YELLOW}Reloading Prometheus configuration...${NC}"
    
    # Reload configuration
    RESPONSE=$(curl -s -X POST "${PROMETHEUS_URL}/-/reload" -w "\n%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" == 2* ]]; then
        echo -e "${GREEN}Success: Prometheus configuration reloaded!${NC}"
        
        # Show current configuration
        echo -e "\n${YELLOW}Current Prometheus Configuration:${NC}"
        curl -s "${PROMETHEUS_URL}/api/v1/status/config" | jq '.data.yaml' | sed 's/\\n/\n/g' | sed 's/^"//; s/"$//'
    else
        echo -e "${RED}Error: Failed to reload Prometheus configuration.${NC}"
        echo -e "${RED}HTTP Status: ${HTTP_CODE}${NC}"
        echo -e "${RED}Response: ${RESPONSE_BODY}${NC}"
        return 1
    fi
    
    return 0
}

# Reload configuration
if reload_config; then
    echo -e "\n${GREEN}Your Prometheus configuration has been reloaded!${NC}"
    echo -e "${YELLOW}You can access Prometheus at:${NC} ${PROMETHEUS_URL}"
else
    echo -e "\n${RED}Failed to reload Prometheus configuration.${NC}"
    exit 1
fi

exit 0 