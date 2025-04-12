#!/bin/bash
# Script to set up the MCP environment

# Set terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || { echo "Failed to change to script directory"; exit 1; }

# Banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}        MCP Environment Setup          ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if .env file exists, if not create from template
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  echo -e "\n${YELLOW}Creating .env file from template...${NC}"
  cp "$SCRIPT_DIR/.env.template" "$SCRIPT_DIR/.env"
  echo -e "${GREEN}Created .env file. Please edit it with your actual API keys.${NC}"
  echo -e "${YELLOW}Would you like to edit it now? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if command -v nano &> /dev/null; then
      nano "$SCRIPT_DIR/.env"
    elif command -v vim &> /dev/null; then
      vim "$SCRIPT_DIR/.env"
    else
      echo -e "${RED}No editor (nano/vim) found. Please edit $SCRIPT_DIR/.env manually.${NC}"
    fi
  fi
else
  echo -e "\n${GREEN}.env file already exists.${NC}"
fi

# Check if Claude config dir exists
CLAUDE_CONFIG_DIR="$HOME/.claude"
if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
  echo -e "\n${YELLOW}Creating Claude config directory...${NC}"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  echo -e "${GREEN}Created $CLAUDE_CONFIG_DIR${NC}"
fi

# Check if Claude config file exists
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/config.json"
if [[ ! -f "$CLAUDE_CONFIG_FILE" ]]; then
  echo -e "\n${YELLOW}Creating Claude config.json from template...${NC}"
  cp "$SCRIPT_DIR/config_template.json" "$CLAUDE_CONFIG_FILE"
  echo -e "${GREEN}Created Claude config file at $CLAUDE_CONFIG_FILE${NC}"
else
  echo -e "\n${YELLOW}Claude config.json already exists. Would you like to update it with MCP settings? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Backup existing config
    cp "$CLAUDE_CONFIG_FILE" "$CLAUDE_CONFIG_FILE.backup"
    echo -e "${GREEN}Backed up existing config to $CLAUDE_CONFIG_FILE.backup${NC}"
    
    # Check if jq is available for JSON manipulation
    if command -v jq &> /dev/null; then
      # Try to update config with jq
      if jq '.mcp_tools = [{"url": "http://localhost:5000/mcp", "name": "mcp__tavily_search"}]' "$CLAUDE_CONFIG_FILE.backup" > "$CLAUDE_CONFIG_FILE"; then
        echo -e "${GREEN}Updated Claude config with MCP settings${NC}"
      else
        echo -e "${RED}Failed to update config with jq. Restoring backup.${NC}"
        cp "$CLAUDE_CONFIG_FILE.backup" "$CLAUDE_CONFIG_FILE"
      fi
    else
      echo -e "${YELLOW}jq not found. Copying template instead (this will overwrite existing settings).${NC}"
      echo -e "${YELLOW}Continue? (y/n)${NC}"
      read -r response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cp "$SCRIPT_DIR/config_template.json" "$CLAUDE_CONFIG_FILE"
        echo -e "${GREEN}Replaced Claude config with template${NC}"
      else
        echo -e "${YELLOW}Skipped config update${NC}"
      fi
    fi
  fi
fi

# Check if uv is installed
if ! command -v uv &> /dev/null; then
  echo -e "\n${YELLOW}uv package manager not found.${NC}"
  echo -e "${YELLOW}Would you like to install it? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${YELLOW}Installing uv...${NC}"
    if command -v pip &> /dev/null; then
      pip install uv
      echo -e "${GREEN}uv installed successfully${NC}"
    else
      echo -e "${RED}pip not found. Please install Python and pip first.${NC}"
    fi
  else
    echo -e "${RED}uv is required for MCP servers to function. Please install it manually.${NC}"
  fi
else
  echo -e "\n${GREEN}uv package manager is already installed.${NC}"
fi

echo -e "\n${GREEN}MCP environment setup complete!${NC}"
echo -e "${BLUE}To start all MCP servers, run:${NC}"
echo -e "  ${YELLOW}./start_all_mcp_servers.sh${NC}"
echo -e "${BLUE}To start just the Tavily MCP server, run:${NC}"
echo -e "  ${YELLOW}./load_tavily_mcp.sh${NC}"
echo -e "${BLUE}Remember to use Claude Code with the MCP tool flag:${NC}"
echo -e "  ${YELLOW}claude-code --mcp-tool=\"http://localhost:5000/mcp\" your_query${NC}"
echo -e "${BLUE}Or without the flag if you've configured ~/.claude/config.json${NC}"