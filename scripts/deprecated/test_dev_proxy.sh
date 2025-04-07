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

# Application-specific metrics URLs
NODEJS_STATUS_URL="http://localhost:3000/nodejs_status"
NEXTJS_STATUS_URL="http://localhost:3001/nextjs_status"
REMIX_STATUS_URL="http://localhost:3002/remix_status"
RUST_STATUS_URL="http://localhost:8000/rust_status"
REACT_STATUS_URL="http://localhost:3003/react_status"

# Application-specific exporter URLs
NODEJS_METRICS_URL="http://localhost:9114/metrics"
NEXTJS_METRICS_URL="http://localhost:9115/metrics"
REMIX_METRICS_URL="http://localhost:9116/metrics"
RUST_METRICS_URL="http://localhost:9117/metrics"
REACT_METRICS_URL="http://localhost:9118/metrics"

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

# Check if the main stub_status endpoint is accessible
echo -e "\n${YELLOW}Checking if the main stub_status endpoint is accessible...${NC}"
if ! curl -s --head "${STUB_STATUS_URL}" > /dev/null; then
    echo -e "${RED}Error: Main stub_status endpoint is not available at ${STUB_STATUS_URL}${NC}"
else
    echo -e "${GREEN}Main stub_status endpoint is accessible at ${STUB_STATUS_URL}${NC}"
fi

# Check if the main metrics exporter is running
echo -e "\n${YELLOW}Checking if the main Nginx metrics exporter is running...${NC}"
if ! curl -s --head "${METRICS_URL}" > /dev/null; then
    echo -e "${RED}Error: Main Nginx metrics exporter is not running at ${METRICS_URL}${NC}"
    echo -e "${YELLOW}Make sure your Docker Compose setup is running with:${NC}"
    echo -e "  docker compose up -d"
else
    echo -e "${GREEN}Main Nginx metrics exporter is running!${NC}"
fi

# Check application-specific status endpoints
echo -e "\n${YELLOW}Checking application-specific status endpoints...${NC}"

# Function to check status endpoint
check_status() {
    local url=$1
    local app=$2
    
    echo -e "${YELLOW}Checking ${app} status endpoint...${NC}"
    if ! curl -s --head "${url}" > /dev/null; then
        echo -e "${RED}Error: ${app} status endpoint is not available at ${url}${NC}"
    else
        echo -e "${GREEN}${app} status endpoint is accessible at ${url}${NC}"
    fi
}

# Function to check metrics exporter
check_exporter() {
    local url=$1
    local app=$2
    
    echo -e "${YELLOW}Checking ${app} metrics exporter...${NC}"
    if ! curl -s --head "${url}" > /dev/null; then
        echo -e "${RED}Error: ${app} metrics exporter is not running at ${url}${NC}"
    else
        echo -e "${GREEN}${app} metrics exporter is running at ${url}${NC}"
    fi
}

# Check all app-specific status endpoints and exporters
check_status "${NODEJS_STATUS_URL}" "Node.js"
check_exporter "${NODEJS_METRICS_URL}" "Node.js"

check_status "${NEXTJS_STATUS_URL}" "Next.js"
check_exporter "${NEXTJS_METRICS_URL}" "Next.js"

check_status "${REMIX_STATUS_URL}" "Remix"
check_exporter "${REMIX_METRICS_URL}" "Remix"

check_status "${RUST_STATUS_URL}" "Rust"
check_exporter "${RUST_METRICS_URL}" "Rust"

check_status "${REACT_STATUS_URL}" "React"
check_exporter "${REACT_METRICS_URL}" "React"

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
echo -e "\n${YELLOW}Checking Prometheus scraping status for all exporters...${NC}"

# Check main Nginx metrics
NGINX_METRICS=$(curl -s "http://localhost:9090/api/v1/query?query=nginx_up" | grep -o '"value":\[.*,"1"\]')
if [[ ! -z "$NGINX_METRICS" ]]; then
    echo -e "${GREEN}Prometheus is successfully scraping main Nginx metrics${NC}"
else
    echo -e "${RED}Prometheus may not be scraping main Nginx metrics correctly${NC}"
fi

# Check application-specific metrics
check_prometheus_metrics() {
    local metric_name=$1
    local app=$2
    local query="$metric_name"_up
    
    local METRICS=$(curl -s "http://localhost:9090/api/v1/query?query=${query}" | grep -o '"value":\[.*,"1"\]')
    if [[ ! -z "$METRICS" ]]; then
        echo -e "${GREEN}Prometheus is successfully scraping ${app} metrics (${query})${NC}"
    else
        echo -e "${RED}Prometheus may not be scraping ${app} metrics correctly${NC}"
    fi
}

check_prometheus_metrics "nodejs" "Node.js"
check_prometheus_metrics "nextjs" "Next.js"
check_prometheus_metrics "remix" "Remix"
check_prometheus_metrics "rust" "Rust"
check_prometheus_metrics "react" "React"

echo -e "\n${GREEN}Development proxy test completed!${NC}"
echo -e "${YELLOW}Access your development proxy at:${NC}"
echo -e "  - http://localhost:3000 → http://localhost:33000 (Node.js)"
echo -e "  - http://localhost:3001 → http://localhost:33001 (Next.js)"
echo -e "  - http://localhost:3002 → http://localhost:33002 (Remix)"
echo -e "  - http://localhost:8000 → http://localhost:38000 (Rust)"
echo -e "  - http://localhost:3003 → http://localhost:33003 (React)"

echo -e "\n${YELLOW}Status Pages:${NC}"
echo -e "  - Main status page: http://localhost:8686/status"
echo -e "  - Node.js status: http://localhost:3000/nodejs_status"
echo -e "  - Next.js status: http://localhost:3001/nextjs_status" 
echo -e "  - Remix status: http://localhost:3002/remix_status"
echo -e "  - Rust status: http://localhost:8000/rust_status"
echo -e "  - React status: http://localhost:3003/react_status"

echo -e "\n${YELLOW}Metrics Endpoints:${NC}"
echo -e "  - Main Nginx metrics: http://localhost:9113/metrics"
echo -e "  - Node.js metrics: http://localhost:9114/metrics"
echo -e "  - Next.js metrics: http://localhost:9115/metrics"
echo -e "  - Remix metrics: http://localhost:9116/metrics"
echo -e "  - Rust metrics: http://localhost:9117/metrics"
echo -e "  - React metrics: http://localhost:9118/metrics"
echo -e "  - Prometheus UI: http://localhost:9090"
echo -e "  - Grafana Dashboard: http://localhost:3333"

exit 0 