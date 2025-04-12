#!/bin/bash
# Script to test MCP servers locally

# Set terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}       MCP Servers Test Suite          ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Failed to change to script directory"; exit 1; }

# Load environment variables from .env file
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo -e "${YELLOW}Loading API keys from .env file...${NC}"
  source "$ENV_FILE"
else
  echo -e "${RED}Error: .env file not found. Please run setup_mcp_env.sh first.${NC}"
  exit 1
fi

# Create a file to store PIDs for cleanup
PID_FILE="$SCRIPT_DIR/.test_pids"
echo -n > "$PID_FILE"

# Function to check if a port is already in use
port_in_use() {
  lsof -i:"$1" &> /dev/null
}

# Function to start an MCP server for testing
start_test_server() {
  local name=$1
  local script=$2
  local port=$3
  local api_key_name=$4
  
  echo -e "\n${YELLOW}Starting $name MCP server for testing...${NC}"
  
  # Check if port is already in use
  if port_in_use "$port"; then
    echo -e "${RED}Error: Port $port is already in use. Cannot start $name MCP server.${NC}"
    return 1
  fi
  
  # Check if script exists and is executable
  if [[ ! -x "$script" ]]; then
    echo -e "${RED}Error: Script $script not found or not executable.${NC}"
    return 1
  fi
  
  # Check if the API key is set
  if [[ -z "${!api_key_name}" ]]; then
    echo -e "${RED}Error: $api_key_name is not set in .env file. Cannot start $name MCP server.${NC}"
    return 1
  fi
  
  # Prepare for server startup
  echo -e "${YELLOW}Setting up for $name server...${NC}"
  local server_dir=$(dirname "$script")
  
  # For testing purposes, let's use the system Python
  # This avoids virtual environment issues in the test script
  echo -e "${YELLOW}Note: Tests use system Python installation${NC}"
  
  # We'll let the script handle its own dependencies
  
  # Start the server with explicit API key
  "$script" --port "$port" --api-key "${!api_key_name}" &
  local pid=$!
  echo "$name:$pid:$port" >> "$PID_FILE"
  
  # Give the server a moment to start
  sleep 5  # Increased wait time to allow for startup
  
  # Verify server is running
  if ! curl -s "http://localhost:$port/health" > /dev/null; then
    echo -e "${RED}Error: $name server failed to start properly${NC}"
    kill "$pid" 2>/dev/null
    return 1
  fi
  
  echo -e "${GREEN}$name MCP server started for testing on port $port (PID: $pid)${NC}"
  return 0
}

# Function to stop all test servers
stop_test_servers() {
  echo -e "\n${YELLOW}Stopping all test servers...${NC}"
  if [[ -f "$PID_FILE" ]]; then
    while IFS=: read -r name pid port || [[ -n "$name" ]]; do
      if ps -p "$pid" > /dev/null; then
        kill "$pid" 2>/dev/null
        echo -e "${GREEN}Stopped $name test server (PID: $pid)${NC}"
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  fi
  echo -e "${GREEN}All test servers stopped.${NC}"
}

# Set up trap to stop servers on exit
trap stop_test_servers EXIT INT TERM

# Function to test a server's health endpoint
test_health_endpoint() {
  local name=$1
  local port=$2
  
  echo -e "\n${YELLOW}Testing $name health endpoint...${NC}"
  
  # Make request to health endpoint
  local response=$(curl -s "http://localhost:$port/health")
  
  # Check response
  if [[ "$response" == *"health"* ]] || [[ "$response" == *"status"* ]]; then
    echo -e "${GREEN}✓ Health endpoint test PASSED${NC}"
    return 0
  else
    echo -e "${RED}✗ Health endpoint test FAILED${NC}"
    echo -e "${YELLOW}Response: $response${NC}"
    return 1
  fi
}

# Function to test a server's MCP config endpoint
test_config_endpoint() {
  local name=$1
  local port=$2
  
  echo -e "\n${YELLOW}Testing $name MCP config endpoint...${NC}"
  
  # Make request to mcp-config endpoint
  local response=$(curl -s "http://localhost:$port/mcp-config")
  
  # Check response
  if [[ "$response" == *"name"* ]] && [[ "$response" == *"description"* ]] && [[ "$response" == *"input_schema"* ]]; then
    echo -e "${GREEN}✓ MCP config endpoint test PASSED${NC}"
    return 0
  else
    echo -e "${RED}✗ MCP config endpoint test FAILED${NC}"
    echo -e "${YELLOW}Response: $response${NC}"
    return 1
  fi
}

# Function to test a server's MCP endpoint
test_mcp_endpoint() {
  local name=$1
  local port=$2
  local query=$3
  
  echo -e "\n${YELLOW}Testing $name MCP endpoint with query: '$query'...${NC}"
  
  # Make request to MCP endpoint
  local response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"inputs\":{\"query\":\"$query\"}}" \
    "http://localhost:$port/mcp")
  
  # Check response
  if [[ "$response" == *"results"* ]]; then
    echo -e "${GREEN}✓ MCP endpoint test PASSED${NC}"
    return 0
  else
    echo -e "${RED}✗ MCP endpoint test FAILED${NC}"
    echo -e "${YELLOW}Response: $response${NC}"
    return 1
  fi
}

# Run tests for Tavily server
echo -e "\n${BLUE}========== Testing Tavily MCP Server ==========${NC}"

if start_test_server "Tavily" "./servers/tavily/tavily_mcp.py" "5001" "TAVILY_API_KEY"; then
  # Test endpoints
  test_health_endpoint "Tavily" "5001"
  test_config_endpoint "Tavily" "5001"
  test_mcp_endpoint "Tavily" "5001" "test query for MCP server"
else
  echo -e "${RED}Cannot run tests for Tavily server due to startup failure${NC}"
fi

# Add more server tests here as you add more MCP servers
# Example:
# echo -e "\n${BLUE}========== Testing Another MCP Server ==========${NC}"
# if start_test_server "Another" "./servers/another/another_mcp.py" "5011" "ANOTHER_API_KEY"; then
#   test_health_endpoint "Another" "5011"
#   test_config_endpoint "Another" "5011"
#   test_mcp_endpoint "Another" "5011" "test query for another MCP server"
# fi

echo -e "\n${BLUE}========== All Tests Completed ==========${NC}"