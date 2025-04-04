#!/bin/bash

# Configuration
STATUS_URL="http://localhost:8686"
STATUS_PAGE_URL="http://localhost:8686/status"
STUB_STATUS_URL="http://localhost:8686/stub_status"
METRICS_URL="http://localhost:9113/metrics"
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
if ! curl -s --head "${STATUS_URL}" > /dev/null; then
    echo -e "${RED}Error: Development proxy is not running at ${STATUS_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}Development proxy is running!${NC}"

# Check if the browser status page is accessible
echo -e "\n${YELLOW}Checking if the browser-friendly status page is accessible...${NC}"
if ! curl -s --head "${STATUS_PAGE_URL}" > /dev/null; then
    echo -e "${RED}Error: Browser status page is not available at ${STATUS_PAGE_URL}${NC}"
else
    echo -e "${GREEN}Browser status page is accessible at ${STATUS_PAGE_URL}${NC}"
fi

# Check if the stub_status endpoint is accessible
echo -e "\n${YELLOW}Checking if the raw stub_status endpoint is accessible...${NC}"
if ! curl -s --head "${STUB_STATUS_URL}" > /dev/null; then
    echo -e "${RED}Error: Raw stub_status endpoint is not available at ${STUB_STATUS_URL}${NC}"
else
    echo -e "${GREEN}Raw stub_status endpoint is accessible at ${STUB_STATUS_URL}${NC}"
fi

# Check if the metrics exporter is running
echo -e "\n${YELLOW}Checking if the Nginx metrics exporter is running...${NC}"
if ! curl -s --head "${METRICS_URL}" > /dev/null; then
    echo -e "${RED}Error: Nginx metrics exporter is not running at ${METRICS_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
else
    echo -e "${GREEN}Nginx metrics exporter is running!${NC}"
fi

# Function to test a port
test_port() {
    local port=$1
    local description=$2
    local expected_codes=${3:-200}
    
    echo -e "\n${YELLOW}Testing port: ${port} (${description})${NC}"
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}" --max-time 2)
    
    # Check if the response matches any of the expected codes
    if [[ "$expected_codes" == *"$RESPONSE"* ]]; then
        echo -e "${GREEN}Success: Port ${port} responded with ${RESPONSE}${NC}"
    elif [[ "$RESPONSE" == "000" ]]; then
        echo -e "${YELLOW}Notice: Port ${port} - Connection refused or timed out (This is normal if ${description} is not running)${NC}"
    # Special handling for proxy ports
    elif [[ ("$RESPONSE" == "404" || "$RESPONSE" == "502") && ("$expected_codes" == "404,502" || "$expected_codes" == "502,404") ]]; then
        echo -e "${YELLOW}Notice: Port ${port} responded with ${RESPONSE} (This is normal if the backend service is not running)${NC}"
    else
        echo -e "${RED}Error: Port ${port} responded with ${RESPONSE} (expected one of: ${expected_codes})${NC}"
    fi
    
    return 0
}

# Test the ports
test_port "8686" "Status page"
# Accept either 404 or 502 for port forwarding tests
test_port "3000" "Node.js app (forwarding to 33000)" "404,502"
test_port "3001" "Next.js app (forwarding to 33001)" "404,502"
test_port "3002" "Remix app (forwarding to 33002)" "404,502"
test_port "8000" "Rust app (forwarding to 38000)" "404,502"
test_port "3003" "React app (forwarding to 33003)" "404,502"

# Get stats from Prometheus
echo -e "\n${YELLOW}Checking Prometheus scraping status for Nginx metrics...${NC}"
# Use a direct query for nginx metrics instead of checking targets
NGINX_METRICS=$(curl -s "http://localhost:9090/api/v1/query?query=nginx_up" | grep -o '"value":\[.*,"1"\]')

if [[ ! -z "$NGINX_METRICS" ]]; then
    echo -e "${GREEN}Prometheus is successfully scraping Nginx metrics${NC}"
else
    echo -e "${RED}Prometheus may not be scraping Nginx metrics correctly${NC}"
    echo -e "${YELLOW}Checking available metrics in Prometheus...${NC}"
    curl -s "http://localhost:9090/api/v1/label/__name__/values" | grep nginx | head -5
fi

echo -e "\n${GREEN}Development proxy test completed!${NC}"
echo -e "${YELLOW}Access your development proxy at:${NC}"
echo -e "  - http://localhost:3000 → http://localhost:33000 (Node.js)"
echo -e "  - http://localhost:3001 → http://localhost:33001 (Next.js)"
echo -e "  - http://localhost:3002 → http://localhost:33002 (Remix)"
echo -e "  - http://localhost:8000 → http://localhost:38000 (Rust)"
echo -e "  - http://localhost:3003 → http://localhost:33003 (React)"
echo -e "${YELLOW}Status Pages:${NC}"
echo -e "  - Text Status: http://localhost:8686"
echo -e "  - HTML Status: http://localhost:8686/status"
echo -e "  - Raw Metrics: http://localhost:8686/stub_status"
echo -e "  - Prometheus Metrics: http://localhost:9113/metrics"
echo -e "  - Grafana Dashboard: http://localhost:3333"

exit 0 