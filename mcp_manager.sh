#!/bin/bash
#
# MCP Server Manager
# A streamlined utility for managing Model Context Protocol (MCP) servers using Smithery.

set -e

# Constants - support both local and global installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# For global installation, allow users to override config location
if [ -z "$MCP_CONFIG_DIR" ]; then
  # Look for config in the current directory first
  if [ -f "./mcp_config.json" ]; then
    CONFIG_DIR="."
  else
    # Otherwise use the script directory
    CONFIG_DIR="$SCRIPT_DIR"
  fi
else
  CONFIG_DIR="$MCP_CONFIG_DIR"
fi

CONFIG_FILE="$CONFIG_DIR/mcp_config.json"
ENV_FILE="$CONFIG_DIR/.env"
LOG_DIR="$CONFIG_DIR/logs"
DIAGNOSTIC_FILE="$LOG_DIR/diagnostic.log"
PROCESS_FILE="$CONFIG_DIR/.mcp_processes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Load environment variables
load_env() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    else
        echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
        
        # If this is a global installation, provide more detailed help
        if [ "$CONFIG_DIR" != "." ] && [ "$CONFIG_DIR" != "$SCRIPT_DIR" ]; then
            echo -e "\nIf you're using a global installation, please:"
            echo -e "1. Create a config directory: ${BOLD}mkdir -p $CONFIG_DIR${NC}"
            echo -e "2. Create an .env file: ${BOLD}cp /path/to/original/repo/.env.template $CONFIG_DIR/.env${NC}"
            echo -e "3. Edit the file with your API keys: ${BOLD}nano $CONFIG_DIR/.env${NC}"
            echo -e "4. Copy the config file: ${BOLD}cp /path/to/original/repo/mcp_config.json $CONFIG_DIR/${NC}"
        else
            echo -e "Please create the .env file with your API keys:"
            echo -e "${BOLD}cp .env.template .env && nano .env${NC}"
        fi
        
        exit 1
    fi
}

# Check for required tools
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Error: Node.js is required but not installed.${NC}"
        echo -e "Please install Node.js v20 or higher: https://nodejs.org/"
        exit 1
    fi
    
    # Check Node.js version
    node_version=$(node -v | cut -d'v' -f2)
    node_major=$(echo "$node_version" | cut -d'.' -f1)
    if [ "$node_major" -lt 20 ]; then
        echo -e "${RED}Error: Node.js v20 or higher is required.${NC}"
        echo -e "Current version: v${node_version}"
        echo -e "Please upgrade Node.js: https://nodejs.org/"
        exit 1
    fi
    
    # Check for npx
    if ! command -v npx &> /dev/null; then
        echo -e "${RED}Error: npx is required but not installed.${NC}"
        echo -e "Please install npm to get npx: https://nodejs.org/"
        exit 1
    fi
    
    # Check for Claude CLI
    if ! command -v claude &> /dev/null; then
        echo -e "${YELLOW}Warning: Claude CLI not found. Install for full functionality.${NC}"
        echo -e "See https://github.com/anthropics/claude-cli for installation instructions."
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq is not installed. This script works best with jq for JSON parsing.${NC}"
        echo -e "Install jq with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    # Check for required API keys
    if [ -z "$SMITHERY_API_KEY" ]; then
        echo -e "${RED}Error: SMITHERY_API_KEY not found in .env file.${NC}"
        echo -e "Please add your Smithery API key to the .env file."
        exit 1
    fi
    
    echo -e "${GREEN}All critical requirements met.${NC}"
}

# Resolve environment variables in string
resolve_env_vars() {
    local input="$1"
    local output="$input"
    
    # Replace ${ENV_VAR} with its value
    while [[ "$output" =~ \$\{([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name}"
        
        # Check if environment variable is set
        if [ -z "$var_value" ]; then
            echo -e "${YELLOW}Warning: Environment variable $var_name is not set${NC}" >&2
            var_value="MISSING_ENV_VAR_$var_name"
        fi
        
        output="${output//\$\{$var_name\}/$var_value}"
    done
    
    echo "$output"
}

# Get server list from config
get_server_list() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
        exit 1
    fi
    
    if command -v jq &> /dev/null; then
        # Validate that the config file is valid JSON
        if ! jq '.' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo -e "${RED}Error: $CONFIG_FILE is not valid JSON.${NC}"
            exit 1
        fi
        
        # Validate that the config file has the required structure
        if ! jq -e '.mcpServers' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo -e "${RED}Error: $CONFIG_FILE is missing the 'mcpServers' object.${NC}"
            exit 1
        fi
        
        # Return the list of servers
        jq -r '.mcpServers | keys[]' "$CONFIG_FILE"
    else
        echo -e "${RED}Error: jq is required for parsing the config file.${NC}"
        exit 1
    fi
}

# Start a specific MCP server
start_server() {
    local server_name="$1"
    
    echo -e "${BOLD}Starting ${server_name} MCP server...${NC}"
    
    # Get server config
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # Check if server exists in config
    if ! jq -e ".mcpServers.\"$server_name\"" "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${RED}Error: Server '$server_name' not found in config file.${NC}"
        return 1
    fi
    
    # Check if server is already running
    local existing_pid=""
    if [ -f "$PROCESS_FILE" ]; then
        existing_pid=$(grep "^${server_name}:" "$PROCESS_FILE" 2>/dev/null | cut -d: -f2)
        if [ -n "$existing_pid" ] && ps -p "$existing_pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}${server_name} MCP server is already running with PID ${existing_pid}${NC}"
            return 0
        fi
    fi
    
    # Get server command
    local command
    command=$(jq -r ".mcpServers.\"$server_name\".command" "$CONFIG_FILE")
    command=$(resolve_env_vars "$command")
    
    # Get server args
    local args
    args=$(jq -r ".mcpServers.\"$server_name\".args | join(\" \")" "$CONFIG_FILE")
    args=$(resolve_env_vars "$args")
    
    # Get environment variables
    local env_vars
    if jq -e ".mcpServers.\"$server_name\".envVars" "$CONFIG_FILE" > /dev/null 2>&1; then
        env_vars=$(jq -r ".mcpServers.\"$server_name\".envVars | to_entries[] | \"\(.key)=\\\"\(.value)\\\"\"" "$CONFIG_FILE")
    fi
    
    # Get port
    local port
    port=$(jq -r ".mcpServers.\"$server_name\".port" "$CONFIG_FILE")
    
    # Get MCP name
    local mcp_name
    mcp_name=$(jq -r ".mcpServers.\"$server_name\".mcpName" "$CONFIG_FILE")
    
    # Create a unique log file for this server
    local log_file="$LOG_DIR/${server_name}.log"
    
    # Build environment variable exports
    local env_exports=""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local resolved_line
            resolved_line=$(resolve_env_vars "$line")
            env_exports="$env_exports $resolved_line"
        fi
    done <<< "$env_vars"
    
    # Build the full command
    local full_command="$command $args"
    
    echo -e "${BLUE}Starting ${server_name} on port ${port}...${NC}"
    echo -e "Command: ${env_exports} ${full_command}"
    
    # Execute the command with environment variables
    eval "${env_exports} ${full_command} > \"$log_file\" 2>&1 &"
    
    # Save the process ID
    local pid=$!
    
    # Remove any existing entries for this server
    if [ -f "$PROCESS_FILE" ]; then
        grep -v "^${server_name}:" "$PROCESS_FILE" > "$PROCESS_FILE.tmp" 2>/dev/null || true
        mv "$PROCESS_FILE.tmp" "$PROCESS_FILE" 2>/dev/null || true
    fi
    
    # Add the new process ID
    echo "${server_name}:${pid}" >> "$PROCESS_FILE"
    
    echo -e "${GREEN}${server_name} MCP server started with PID ${pid}${NC}"
    echo -e "Logs available at: ${log_file}"
    
    # Register the server with Claude CLI - unregister first to avoid duplicates
    if command -v claude &> /dev/null; then
        echo -e "${BLUE}Registering ${server_name} with Claude CLI...${NC}"
        claude mcp remove "$mcp_name" > /dev/null 2>&1 || true
        claude mcp add "$mcp_name" "http://localhost:${port}" > /dev/null 2>&1
        echo -e "${GREEN}${server_name} registered with Claude CLI as ${mcp_name}${NC}"
    fi
}

# Stop a specific MCP server
stop_server() {
    local server_name="$1"
    
    echo -e "${BLUE}Stopping ${server_name} MCP server...${NC}"
    
    if [ ! -f "$PROCESS_FILE" ]; then
        echo -e "${YELLOW}No process file found. All servers are likely already stopped.${NC}"
        return
    fi
    
    # Get the PID for this server
    local pid
    pid=$(grep "^${server_name}:" "$PROCESS_FILE" 2>/dev/null | cut -d: -f2)
    
    if [ -n "$pid" ]; then
        # Kill the process
        kill -15 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
        
        # Remove the entry from the process file
        grep -v "^${server_name}:" "$PROCESS_FILE" > "$PROCESS_FILE.tmp" 2>/dev/null || true
        mv "$PROCESS_FILE.tmp" "$PROCESS_FILE" 2>/dev/null || true
        
        echo -e "${GREEN}${server_name} MCP server stopped${NC}"
    else
        echo -e "${YELLOW}No running process found for ${server_name}${NC}"
    fi
    
    # Get MCP name from config
    if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
        local mcp_name
        mcp_name=$(jq -r ".mcpServers.\"$server_name\".mcpName" "$CONFIG_FILE" 2>/dev/null)
        
        # Unregister the server from Claude CLI
        if [ -n "$mcp_name" ] && command -v claude &> /dev/null; then
            echo -e "${BLUE}Unregistering ${server_name} from Claude CLI...${NC}"
            claude mcp remove "$mcp_name" > /dev/null 2>&1 || true
            echo -e "${GREEN}${server_name} unregistered from Claude CLI${NC}"
        fi
    fi
}

# Start all MCP servers
start_all_servers() {
    echo -e "${BOLD}Starting all MCP servers...${NC}"
    
    # Create process file if it doesn't exist
    if [ ! -f "$PROCESS_FILE" ]; then
        touch "$PROCESS_FILE"
    fi
    
    # Get list of servers from config
    local servers
    servers=$(get_server_list)
    
    # Start each server
    while IFS= read -r server; do
        if [ -n "$server" ]; then
            start_server "$server"
        fi
    done <<< "$servers"
    
    echo -e "${GREEN}All servers started.${NC}"
    echo -e "Use '${BOLD}./mcp_manager.sh status${NC}' to check server status."
}

# Stop all MCP servers
stop_all_servers() {
    echo -e "${BOLD}Stopping all MCP servers...${NC}"
    
    # Check if process file exists
    if [ ! -f "$PROCESS_FILE" ]; then
        echo -e "${YELLOW}No running MCP servers found.${NC}"
        return
    fi
    
    # Stop each server
    while read -r line; do
        if [ -n "$line" ]; then
            local server_name
            server_name=$(echo "$line" | cut -d: -f1)
            stop_server "$server_name"
        fi
    done < "$PROCESS_FILE"
    
    # Remove process file
    rm -f "$PROCESS_FILE"
    
    echo -e "${GREEN}All servers stopped successfully.${NC}"
}

# Check server status
check_status() {
    echo -e "${BOLD}MCP Server Status:${NC}"
    
    local servers
    servers=$(get_server_list)
    local any_running=false
    
    # Check each server
    while IFS= read -r server; do
        if [ -n "$server" ]; then
            local status
            local pid
            
            if [ -f "$PROCESS_FILE" ]; then
                pid=$(grep "^${server}:" "$PROCESS_FILE" 2>/dev/null | cut -d: -f2)
            fi
            
            if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
                status="${GREEN}Running (PID: ${pid})${NC}"
                any_running=true
                
                # Clean up process file entry if needed
                if ! grep -q "^${server}:${pid}$" "$PROCESS_FILE" 2>/dev/null; then
                    # Remove old entries
                    grep -v "^${server}:" "$PROCESS_FILE" > "$PROCESS_FILE.tmp" 2>/dev/null || true
                    mv "$PROCESS_FILE.tmp" "$PROCESS_FILE" 2>/dev/null || true
                    # Add correct entry
                    echo "${server}:${pid}" >> "$PROCESS_FILE"
                fi
            else
                status="${RED}Not Running${NC}"
                
                # Remove stale entries from process file
                if [ -n "$pid" ] && [ -f "$PROCESS_FILE" ]; then
                    grep -v "^${server}:" "$PROCESS_FILE" > "$PROCESS_FILE.tmp" 2>/dev/null || true
                    mv "$PROCESS_FILE.tmp" "$PROCESS_FILE" 2>/dev/null || true
                fi
            fi
            
            local port
            port=$(jq -r ".mcpServers.\"$server\".port" "$CONFIG_FILE" 2>/dev/null)
            
            local mcp_name
            mcp_name=$(jq -r ".mcpServers.\"$server\".mcpName" "$CONFIG_FILE" 2>/dev/null)
            
            printf "%-15s Port: %-6s MCP Name: %-20s Status: %b\n" "$server" "$port" "$mcp_name" "$status"
        fi
    done <<< "$servers"
    
    if [ "$any_running" = false ]; then
        echo -e "\n${YELLOW}No servers are currently running. Use '${BOLD}./mcp_manager.sh start${NC}${YELLOW}' to start them.${NC}"
    fi
    
    # Check Claude MCP list
    if command -v claude &> /dev/null; then
        echo -e "\n${BOLD}Claude MCP Servers:${NC}"
        claude mcp list || echo -e "${YELLOW}Failed to get Claude MCP list${NC}"
        
        # Check for potential issues with Claude MCP registration
        if [ "$any_running" = true ]; then
            echo -e "\n${BOLD}Verifying Claude MCP registrations:${NC}"
            local claude_mcps
            claude_mcps=$(claude mcp list 2>/dev/null | grep -o 'Name: [^ ]*' | cut -d' ' -f2)
            
            while IFS= read -r server; do
                if [ -n "$server" ]; then
                    local mcp_name
                    mcp_name=$(jq -r ".mcpServers.\"$server\".mcpName" "$CONFIG_FILE" 2>/dev/null)
                    local pid
                    
                    if [ -f "$PROCESS_FILE" ]; then
                        pid=$(grep "^${server}:" "$PROCESS_FILE" 2>/dev/null | cut -d: -f2)
                    fi
                    
                    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
                        # Just check if the MCP name exists in the list
                        if ! claude mcp list 2>/dev/null | grep -q "$mcp_name"; then
                            echo -e "${YELLOW}Warning: ${server} is running but not registered with Claude. Run '${BOLD}./mcp_manager.sh restart${NC}${YELLOW}' to fix.${NC}"
                        fi
                    fi
                fi
            done <<< "$servers"
        fi
    fi
}

# View logs for a specific server or all servers
view_logs() {
    local server_name="$1"
    
    if [ -n "$server_name" ]; then
        # View logs for a specific server
        local log_file="$LOG_DIR/${server_name}.log"
        
        if [ -f "$log_file" ]; then
            echo -e "${BOLD}Logs for ${server_name} MCP server:${NC}"
            tail -f "$log_file"
        else
            echo -e "${RED}No logs found for ${server_name}${NC}"
        fi
    else
        # View logs for all servers
        echo -e "${BOLD}Recent logs from all MCP servers:${NC}"
        
        local servers
        servers=$(get_server_list)
        
        while IFS= read -r server; do
            if [ -n "$server" ]; then
                local log_file="$LOG_DIR/${server}.log"
                
                if [ -f "$log_file" ]; then
                    echo -e "${BOLD}=== ${server} ====${NC}"
                    tail -n 20 "$log_file"
                    echo -e "\n"
                fi
            fi
        done <<< "$servers"
        
        echo -e "For continuous log monitoring, use: ${BOLD}./mcp_manager.sh logs <server_name>${NC}"
    fi
}

# Run diagnostics
run_diagnostics() {
    echo -e "${BOLD}Running MCP Server Diagnostics...${NC}"
    
    # Create diagnostic log
    {
        echo "===== MCP Server Diagnostics ====="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "===== Environment ====="
        if [ -f "$ENV_FILE" ]; then
            echo "Environment file exists: $ENV_FILE"
            
            # Check API keys (without showing them)
            for api_var in SMITHERY_API_KEY TAVILY_API_KEY FIRECRAWL_API_KEY OPENROUTER_API_KEY; do
                if [ -n "${!api_var}" ]; then
                    echo "$api_var: Set"
                else
                    echo "$api_var: Not set"
                fi
            done
        else
            echo "Environment file not found: $ENV_FILE"
        fi
        echo ""
        
        echo "===== Config File ====="
        if [ -f "$CONFIG_FILE" ]; then
            echo "Config file exists: $CONFIG_FILE"
            echo "Servers defined: $(jq -r '.mcpServers | keys | join(", ")' "$CONFIG_FILE")"
        else
            echo "Config file not found: $CONFIG_FILE"
        fi
        echo ""
        
        echo "===== Server Status ====="
        if [ -f "$PROCESS_FILE" ]; then
            echo "Running servers:"
            while read -r line; do
                if [ -n "$line" ]; then
                    local server_name pid
                    server_name=$(echo "$line" | cut -d: -f1)
                    pid=$(echo "$line" | cut -d: -f2)
                    
                    # Check if process is running
                    if ps -p "$pid" > /dev/null 2>&1; then
                        echo "$server_name: Running (PID: $pid)"
                    else
                        echo "$server_name: Not Running (PID: $pid - process dead)"
                    fi
                fi
            done < "$PROCESS_FILE"
        else
            echo "No server process file found"
        fi
        echo ""
        
        echo "===== Network ====="
        echo "MCP ports:"
        
        local servers
        servers=$(get_server_list)
        
        while IFS= read -r server; do
            if [ -n "$server" ]; then
                local port
                port=$(jq -r ".mcpServers.\"$server\".port" "$CONFIG_FILE" 2>/dev/null)
                
                if [ -n "$port" ]; then
                    if command -v nc &> /dev/null; then
                        echo "$server ($port): $(nc -z localhost "$port" 2>/dev/null && echo "Open" || echo "Closed")"
                    else
                        echo "$server: Port $port (Unable to check - nc command not available)"
                    fi
                fi
            fi
        done <<< "$servers"
        echo ""
        
        echo "===== Claude CLI ====="
        if command -v claude &> /dev/null; then
            echo "Claude CLI version: $(claude --version 2>/dev/null || echo "Unable to determine")"
            echo "Registered MCP servers:"
            claude mcp list 2>/dev/null || echo "Failed to get MCP list"
        else
            echo "Claude CLI not installed"
        fi
        echo ""
        
        echo "===== Server Logs ====="
        local servers
        servers=$(get_server_list)
        
        while IFS= read -r server; do
            if [ -n "$server" ]; then
                local log_file="$LOG_DIR/${server}.log"
                
                if [ -f "$log_file" ]; then
                    echo "=== $server ==="
                    tail -n 10 "$log_file"
                    echo ""
                else
                    echo "No log file for $server"
                fi
            fi
        done <<< "$servers"
        
        echo "===== Node.js Info ====="
        if command -v node &> /dev/null; then
            echo "Node.js version: $(node -v)"
            echo "npm version: $(npm -v 2>/dev/null || echo "Not available")"
            echo "npx version: $(npx -v 2>/dev/null || echo "Not available")"
        else
            echo "Node.js not installed"
        fi
        
    } > "$DIAGNOSTIC_FILE"
    
    echo -e "${GREEN}Diagnostics complete.${NC}"
    echo -e "Diagnostic report saved to: ${DIAGNOSTIC_FILE}"
    echo -e "Run ${BOLD}cat ${DIAGNOSTIC_FILE}${NC} to view the full report."
}

# Setup the configuration directory for global installation
setup_config() {
    local target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        target_dir="$HOME/.mcp-manager"
    fi
    
    echo -e "${BOLD}Setting up configuration directory at: $target_dir${NC}"
    
    # Create the directory structure
    mkdir -p "$target_dir/logs"
    
    # Copy the template .env file if it exists
    if [ -f "$SCRIPT_DIR/.env.template" ]; then
        cp "$SCRIPT_DIR/.env.template" "$target_dir/.env"
        echo -e "${GREEN}Copied .env.template to $target_dir/.env${NC}"
        echo -e "${YELLOW}Remember to edit this file with your actual API keys!${NC}"
    else
        echo -e "${YELLOW}Could not find .env.template, creating an empty .env file${NC}"
        echo "# Add your API keys here" > "$target_dir/.env"
        echo "SMITHERY_API_KEY=your_smithery_key_here" >> "$target_dir/.env"
        echo "TAVILY_API_KEY=your_tavily_key_here" >> "$target_dir/.env"
        echo "FIRECRAWL_API_KEY=your_firecrawl_key_here" >> "$target_dir/.env"
        echo "OPENROUTER_API_KEY=your_openrouter_key_here" >> "$target_dir/.env"
    fi
    
    # Copy the config file if it exists
    if [ -f "$SCRIPT_DIR/mcp_config.json" ]; then
        cp "$SCRIPT_DIR/mcp_config.json" "$target_dir/mcp_config.json"
        echo -e "${GREEN}Copied mcp_config.json to $target_dir/mcp_config.json${NC}"
    else
        echo -e "${YELLOW}Could not find mcp_config.json, creating a basic configuration${NC}"
        echo '{
  "mcpServers": {
    "tavily": {
      "command": "npx",
      "args": [
        "-y",
        "@smithery/cli@latest",
        "run",
        "@tavily-ai/tavily-mcp",
        "--key",
        "${SMITHERY_API_KEY}"
      ],
      "envVars": {
        "TAVILY_API_KEY": "${TAVILY_API_KEY}"
      },
      "port": 3000,
      "mcpName": "tavily-search"
    }
  }
}' > "$target_dir/mcp_config.json"
    fi
    
    echo -e "${GREEN}Configuration directory setup complete!${NC}"
    echo -e "To use this configuration directory, run:"
    echo -e "${BOLD}export MCP_CONFIG_DIR=$target_dir${NC}"
    echo -e "You may want to add this to your .bashrc or .zshrc file."
}

# Print usage information
print_usage() {
    echo -e "${BOLD}MCP Server Manager${NC}"
    echo -e "A utility for managing Model Context Protocol (MCP) servers with Smithery."
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ./mcp_manager.sh [command] [arguments]"
    echo
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}start${NC}           Start all configured MCP servers"
    echo -e "  ${GREEN}stop${NC}            Stop all running MCP servers"
    echo -e "  ${GREEN}status${NC}          Check status of all MCP servers"
    echo -e "  ${GREEN}logs${NC} [server]   View logs for all or a specific server"
    echo -e "  ${GREEN}diagnose${NC}        Run diagnostics and troubleshooting"
    echo -e "  ${GREEN}setup${NC} [dir]     Set up configuration directory (for global installation)"
    echo -e "  ${GREEN}help${NC}            Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ./mcp_manager.sh start       # Start all servers"
    echo -e "  ./mcp_manager.sh logs tavily # View tavily server logs"
    echo -e "  ./mcp_manager.sh setup       # Set up default config directory in ~/.mcp-manager"
}

# Setup trap for graceful shutdown
cleanup() {
    echo -e "\n${YELLOW}Received termination signal. Cleaning up...${NC}"
    if [ -f "$PROCESS_FILE" ]; then
        while read -r line; do
            if [ -n "$line" ]; then
                local server_name pid
                server_name=$(echo "$line" | cut -d: -f1)
                pid=$(echo "$line" | cut -d: -f2)
                
                # Kill the process
                kill -15 "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
                echo -e "${GREEN}${server_name} MCP server stopped${NC}"
            fi
        done < "$PROCESS_FILE"
        rm -f "$PROCESS_FILE"
    fi
    exit 0
}

# Main function to handle commands
main() {
    local command="$1"
    shift
    
    # Setup trap for graceful shutdown
    trap cleanup INT TERM
    
    # If no command provided, use "help"
    if [ -z "$command" ]; then
        command="help"
    fi
    
    # Load environment variables if not using setup or help
    if [ "$command" != "setup" ] && [ "$command" != "help" ]; then
        load_env
        check_requirements
    fi
    
    # Process commands
    case "$command" in
        start)
            start_all_servers
            ;;
        stop)
            stop_all_servers
            ;;
        restart)
            stop_all_servers
            start_all_servers
            ;;
        status)
            check_status
            ;;
        logs)
            view_logs "$1"
            ;;
        diagnose)
            run_diagnostics
            ;;
        setup)
            setup_config "$1"
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            print_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"