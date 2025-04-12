#!/bin/bash
# Script to start all MCP servers with their respective API keys and ports

# Set terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}       MCP Servers Control Panel       ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Failed to change to script directory"; exit 1; }

# Port allocation strategy:
# - Port 5000 is reserved for system use
# - Each service gets its own port range:
#   - Tavily: 5001-5009
#   - Service2: 5011-5019
#   - Service3: 5021-5029
#   - etc.
# - First digit after 5 indicates the service (0=system, 1=Tavily, 2=Service2, etc.)
# - Last digit allows for multiple instances of the same service if needed

# Check and setup virtual environment
VENV_DIR="$SCRIPT_DIR/venv"
if [[ ! -d "$VENV_DIR" ]]; then
  echo -e "${YELLOW}Creating virtual environment...${NC}"
  # Check if uv is available
  if command -v uv &> /dev/null; then
    uv venv "$VENV_DIR"
  else
    echo -e "${YELLOW}uv not found, using standard venv...${NC}"
    python3 -m venv "$VENV_DIR"
  fi
  echo -e "${GREEN}Virtual environment created at $VENV_DIR${NC}"
fi

# Activate virtual environment
echo -e "${YELLOW}Activating virtual environment...${NC}"
source "$VENV_DIR/bin/activate"

# Install dependencies from requirements file
echo -e "${YELLOW}Checking and installing dependencies...${NC}"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
if [[ -f "$REQUIREMENTS_FILE" ]]; then
  if command -v uv &> /dev/null; then
    uv pip install -r "$REQUIREMENTS_FILE"
  else
    pip install -r "$REQUIREMENTS_FILE"
  fi
  echo -e "${GREEN}Dependencies installed from $REQUIREMENTS_FILE${NC}"
else
  echo -e "${RED}Warning: Requirements file not found at $REQUIREMENTS_FILE${NC}"
  echo -e "${YELLOW}Installing minimal dependencies...${NC}"
  if command -v uv &> /dev/null; then
    uv pip install tavily-python requests
  else
    pip install tavily-python requests
  fi
  echo -e "${GREEN}Minimal dependencies installed${NC}"
fi

# Load environment variables from .env file
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo -e "${YELLOW}Loading API keys from .env file...${NC}"
  # Use source to load the .env file into the current shell
  source "$ENV_FILE"
else
  echo -e "${RED}Error: .env file not found. Please run setup_mcp_env.sh first.${NC}"
  exit 1
fi

# Configuration for all MCP servers
# Format: name|script_path|port|api_key_name
# Add new MCP servers here
declare -a MCP_SERVERS=(
  "tavily|./servers/tavily/tavily_mcp.py|5001|TAVILY_API_KEY"
  # Add more servers here in the same format
  # "service2|./servers/service2/service2_mcp.py|5011|SERVICE2_API_KEY"
  # "service3|./servers/service3/service3_mcp.py|5021|SERVICE3_API_KEY"
)

# Create a file to store PIDs
PID_FILE="$SCRIPT_DIR/.mcp_pids"
echo -n > "$PID_FILE"

# Function to check if a port is already in use
port_in_use() {
  lsof -i:"$1" &> /dev/null
}

# Function to start an MCP server
start_mcp_server() {
  local name=$1
  local script=$2
  local port=$3
  local api_key_name=$4
  
  echo -e "\n${YELLOW}Starting $name MCP server...${NC}"
  
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
  
  # Start the server (API key is already exported from .env)
  "$script" --port "$port" &
  local pid=$!
  
  # Give the server a moment to start
  sleep 2
  
  # Check if server is running by hitting the health endpoint
  if curl -s "http://localhost:$port/health" > /dev/null; then
    echo -e "${GREEN}$name MCP server started successfully on port $port (PID: $pid)${NC}"
    echo "$name:$pid:$port" >> "$PID_FILE"
    return 0
  else
    echo -e "${RED}Error: Failed to start $name MCP server${NC}"
    kill "$pid" 2>/dev/null
    return 1
  fi
}

# Function to stop all MCP servers
stop_all_servers() {
  echo -e "\n${YELLOW}Stopping all MCP servers...${NC}"
  if [[ -f "$PID_FILE" ]]; then
    while IFS=: read -r name pid port || [[ -n "$name" ]]; do
      if ps -p "$pid" > /dev/null; then
        kill "$pid" 2>/dev/null
        echo -e "${GREEN}Stopped $name MCP server (PID: $pid)${NC}"
      else
        echo -e "${YELLOW}$name MCP server (PID: $pid) was not running${NC}"
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  else
    echo -e "${YELLOW}No PID file found. No servers to stop.${NC}"
  fi
  echo -e "${GREEN}All MCP servers stopped.${NC}"
  exit 0
}

# Setup trap to stop all servers on exit
trap stop_all_servers INT TERM EXIT

# Start all MCP servers
echo -e "${YELLOW}Starting all MCP servers...${NC}"
started_count=0
total_count=${#MCP_SERVERS[@]}

for server_config in "${MCP_SERVERS[@]}"; do
  IFS='|' read -r name script port api_key_name <<< "$server_config"
  
  # Start the server
  if start_mcp_server "$name" "$script" "$port" "$api_key_name"; then
    ((started_count++))
  fi
done

echo -e "\n${GREEN}Started $started_count out of $total_count MCP servers${NC}"

# Print Claude Code usage instructions
echo -e "\n${YELLOW}To use in Claude Code with all available MCP tools:${NC}"
mcp_flags=""

if [[ -f "$PID_FILE" ]]; then
  while IFS=: read -r name pid port || [[ -n "$name" ]]; do
    mcp_flags+="--mcp-tool=\"http://localhost:$port/mcp\" "
  done < "$PID_FILE"
  
  echo -e "${BLUE}claude-code $mcp_flags your_query${NC}"
  
  # Also show configuration for config.json
  echo -e "\n${YELLOW}Or add to your ~/.claude/config.json:${NC}"
  echo -e "${BLUE}{"
  echo -e "  \"mcp_tools\": ["
  first=true
  while IFS=: read -r name pid port || [[ -n "$name" ]]; do
    if $first; then
      first=false
    else
      echo -e "    },"
    fi
    echo -e "    {"
    echo -e "      \"url\": \"http://localhost:$port/mcp\","
    echo -e "      \"name\": \"mcp__${name}_search\""
  done < "$PID_FILE"
  echo -e "    }"
  echo -e "  ]"
  echo -e "}${NC}"
else
  echo -e "${RED}No MCP servers were started${NC}"
fi

echo -e "\n${YELLOW}MCP servers are running. Press Ctrl+C to stop all servers.${NC}"

# Keep the script running until Ctrl+C is pressed
while true; do
  sleep 1
done