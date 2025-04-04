#!/bin/bash

# Configuration
PROXY_URL="http://localhost:8080"
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
if ! curl -s --head "${PROXY_URL}" > /dev/null; then
    echo -e "${RED}Error: Development proxy is not running at ${PROXY_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}Development proxy is running!${NC}"

# Function to test a proxy route
test_route() {
    local route=$1
    local expected_code=${2:-200}
    
    echo -e "\n${YELLOW}Testing route: ${route}${NC}"
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${PROXY_URL}${route}")
    
    if [[ "$RESPONSE" == "$expected_code" ]]; then
        echo -e "${GREEN}Success: ${route} responded with ${RESPONSE}${NC}"
    else
        echo -e "${RED}Error: ${route} responded with ${RESPONSE} (expected ${expected_code})${NC}"
    fi
    
    return 0
}

# Test the proxy routes
test_route "/"
test_route "/nodejs/" 404 # This will likely 404 unless your NodeJS app is running
test_route "/nextjs/" 404 # This will likely 404 unless your NextJS app is running
test_route "/remix/" 404 # This will likely 404 unless your Remix app is running
test_route "/rust/" 404 # This will likely 404 unless your Rust app is running
test_route "/react/" 404 # This will likely 404 unless your React app is running

# Get stats from Prometheus
echo -e "\n${YELLOW}Checking Prometheus scraping status for Nginx metrics...${NC}"
SCRAPE_STATUS=$(curl -s "http://localhost:9090/api/v1/targets" | grep -o '"nginx_exporter".*"state":"[^"]*"' | head -1)

if [[ $SCRAPE_STATUS == *'"state":"up"'* ]]; then
    echo -e "${GREEN}Prometheus is successfully scraping Nginx metrics${NC}"
else
    echo -e "${RED}Prometheus may not be scraping Nginx metrics correctly: ${SCRAPE_STATUS}${NC}"
fi

echo -e "\n${GREEN}Development proxy test completed!${NC}"
echo -e "${YELLOW}Access your development proxy at:${NC} ${PROXY_URL}"
echo -e "${YELLOW}Access the Nginx metrics at:${NC} http://localhost:9113/metrics"
echo -e "${YELLOW}View the Nginx dashboard in Grafana at:${NC} http://localhost:3333"

exit 0 