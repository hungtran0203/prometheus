#!/bin/bash

# Configuration
METRICS_URL="http://localhost:80"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${YELLOW}====================================${NC}"
echo -e "${YELLOW}   Development Proxy Test Tool      ${NC}"
echo -e "${YELLOW}====================================${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl to use this script.${NC}"
    exit 1
fi

# Check if the proxy is running
echo -e "\n${YELLOW}Checking if the development proxy is running...${NC}"
if ! curl -s --head "${METRICS_URL}" > /dev/null; then
    echo -e "${RED}Error: Development proxy is not running at ${METRICS_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}Development proxy is running!${NC}"

# Function to test a port
test_port() {
    local port=$1
    local description=$2
    local expected_code=${3:-200}
    
    echo -e "\n${YELLOW}Testing port: ${port} (${description})${NC}"
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}" --max-time 2)
    
    if [[ "$RESPONSE" == "$expected_code" ]]; then
        echo -e "${GREEN}Success: Port ${port} responded with ${RESPONSE}${NC}"
    elif [[ "$RESPONSE" == "000" ]]; then
        echo -e "${YELLOW}Notice: Port ${port} - Connection refused or timed out (This is normal if ${description} is not running)${NC}"
    else
        echo -e "${RED}Error: Port ${port} responded with ${RESPONSE} (expected ${expected_code})${NC}"
    fi
    
    return 0
}

# Test the ports
test_port "80" "Status page"
test_port "3000" "Node.js app (forwarding to 33000)" 000
test_port "3001" "Next.js app (forwarding to 33001)" 000
test_port "3002" "Remix app (forwarding to 33002)" 000
test_port "8000" "Rust app (forwarding to 38000)" 000
test_port "3003" "React app (forwarding to 33003)" 000

# Get stats from Prometheus
echo -e "\n${YELLOW}Checking Prometheus scraping status for Nginx metrics...${NC}"
SCRAPE_STATUS=$(curl -s "http://localhost:9090/api/v1/targets" | grep -o '"nginx_exporter".*"state":"[^"]*"' | head -1)

if [[ $SCRAPE_STATUS == *'"state":"up"'* ]]; then
    echo -e "${GREEN}Prometheus is successfully scraping Nginx metrics${NC}"
else
    echo -e "${RED}Prometheus may not be scraping Nginx metrics correctly: ${SCRAPE_STATUS}${NC}"
fi

echo -e "\n${GREEN}Development proxy test completed!${NC}"
echo -e "${YELLOW}Access your development proxy at:${NC}"
echo -e "  - http://localhost:3000 → http://localhost:33000 (Node.js)"
echo -e "  - http://localhost:3001 → http://localhost:33001 (Next.js)"
echo -e "  - http://localhost:3002 → http://localhost:33002 (Remix)"
echo -e "  - http://localhost:8000 → http://localhost:38000 (Rust)"
echo -e "  - http://localhost:3003 → http://localhost:33003 (React)"
echo -e "${YELLOW}Access the Nginx metrics at:${NC} http://localhost:9113/metrics"
echo -e "${YELLOW}View the Nginx dashboard in Grafana at:${NC} http://localhost:3333"

exit 0 