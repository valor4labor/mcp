#!/bin/bash
# Script to start Tavily MCP server and register it with Claude Code

# Set terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Failed to change to script directory"; exit 1; }

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

# Install dependencies if needed
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! python -c "import tavily" 2>/dev/null; then
  echo -e "${YELLOW}Installing dependencies...${NC}"
  if command -v uv &> /dev/null; then
    uv pip install tavily-python requests
  else
    pip install tavily-python requests
  fi
  echo -e "${GREEN}Dependencies installed${NC}"
else
  echo -e "${GREEN}Dependencies already installed${NC}"
fi

# Load environment variables from .env file
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo -e "${YELLOW}Loading API keys from .env file...${NC}"
  # Use source to load the .env file into the current shell
  source "$ENV_FILE"
fi

# Check if TAVILY_API_KEY is set
if [ -z "$TAVILY_API_KEY" ]; then
  echo -e "${RED}Error: TAVILY_API_KEY environment variable is not set${NC}"
  echo -e "${YELLOW}Please set it with: export TAVILY_API_KEY=your-api-key${NC}"
  echo -e "${YELLOW}Or add it to your .env file${NC}"
  exit 1
fi

# Start the MCP server in the background
echo -e "${YELLOW}Starting Tavily MCP server...${NC}"
./servers/tavily/tavily_mcp.py --host localhost --port 5001 &
SERVER_PID=$!

# Give the server a moment to start
sleep 2

# Check if server is running
if ! curl -s http://localhost:5001/health > /dev/null; then
  echo "Error: Failed to start Tavily MCP server"
  exit 1
fi

echo "Tavily MCP server is running (PID: $SERVER_PID)"
echo "To use in Claude Code, add mcp__tavily_search to your command:"
echo ""
echo "claude-code --mcp-tool=\"http://localhost:5001/mcp\" query"
echo ""
echo "Press Ctrl+C to stop the server"

# Wait for user to press Ctrl+C
trap "kill $SERVER_PID; echo 'Tavily MCP server stopped'; exit 0" INT
wait