#!/bin/bash
#
# MCP Server Manager
# A streamlined utility for managing Model Context Protocol (MCP) servers using the Smithery registry.

set -e

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.mcp_config"
ENV_FILE="$SCRIPT_DIR/.env"
LOG_DIR="$SCRIPT_DIR/logs"
DIAGNOSTIC_FILE="$LOG_DIR/diagnostic.log"
PROCESS_FILE="$SCRIPT_DIR/.mcp_processes"
SERVER_CONFIG_DIR="$SCRIPT_DIR/.server_configs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$SERVER_CONFIG_DIR"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Default servers to manage
DEFAULT_SERVERS="tavily firecrawl openrouter"

# Check for required tools
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed.${NC}"
        exit 1
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq is not installed. This script works best with jq for JSON parsing.${NC}"
        echo -e "Install jq with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    # Check for Claude CLI
    if ! command -v claude &> /dev/null; then
        echo -e "${YELLOW}Warning: Claude CLI not found. Install for full functionality.${NC}"
        echo -e "See https://github.com/anthropics/claude-cli for installation instructions."
    fi
    
    # Check for Smithery API key
    if [ -z "$SMITHERY_API_KEY" ]; then
        echo -e "${RED}Error: SMITHERY_API_KEY not found in .env file.${NC}"
        echo -e "Please add your Smithery API key to the .env file."
        echo -e "Get your API key from: https://smithery.ai/"
        exit 1
    fi
    
    echo -e "${GREEN}All critical requirements met.${NC}"
}

# Get server info from Smithery Registry API
fetch_server_info() {
    local server_name="$1"
    
    echo -e "${BLUE}Fetching server information for ${server_name}...${NC}"
    
    # Query the Smithery Registry API
    local response
    response=$(curl -s -H "Authorization: Bearer $SMITHERY_API_KEY" \
        "https://registry.smithery.ai/servers?q=${server_name}")
    
    # Save the server configuration
    echo "$response" > "$SERVER_CONFIG_DIR/${server_name}.json"
    
    # Extract and return the server URL if using jq
    if command -v jq &> /dev/null; then
        local server_url
        server_url=$(echo "$response" | jq -r '.data[0].url')
        echo "$server_url"
    else
        echo "Server information saved to $SERVER_CONFIG_DIR/${server_name}.json"
    fi
}

# Start a specific MCP server
start_server() {
    local server_name="$1"
    local api_key_var="${server_name^^}_API_KEY"  # Convert to uppercase
    
    # Get the API key for this server
    local api_key="${!api_key_var}"
    
    if [ -z "$api_key" ]; then
        echo -e "${YELLOW}Warning: No API key found for ${server_name}.${NC}"
        echo -e "Add ${api_key_var} to your .env file for full functionality."
    fi
    
    echo -e "${BLUE}Starting ${server_name} MCP server...${NC}"
    
    # Fetch server information from Smithery
    local server_info
    server_info=$(fetch_server_info "$server_name")
    
    # Create a unique log file for this server
    local log_file="$LOG_DIR/${server_name}.log"
    
    # Start the server based on its configuration
    # For demonstration, using a simple npx command
    # In a real implementation, this would parse the server configuration from Smithery
    
    if [ "$server_name" = "tavily" ]; then
        TAVILY_API_KEY="$api_key" npx -y tavily-mcp@latest > "$log_file" 2>&1 &
    elif [ "$server_name" = "firecrawl" ]; then
        FIRECRAWL_API_KEY="$api_key" npx -y @mendable/firecrawl-mcp-server@latest > "$log_file" 2>&1 &
    elif [ "$server_name" = "openrouter" ]; then
        OPENROUTER_API_KEY="$api_key" npx -y openrouter-mcp@latest > "$log_file" 2>&1 &
    else
        echo -e "${RED}Unknown server: ${server_name}${NC}"
        return 1
    fi
    
    # Save the process ID
    local pid=$!
    echo "${server_name}:${pid}" >> "$PROCESS_FILE"
    
    echo -e "${GREEN}${server_name} MCP server started with PID ${pid}${NC}"
    echo -e "Logs available at: ${log_file}"
    
    # Register the server with Claude CLI
    if command -v claude &> /dev/null; then
        echo -e "${BLUE}Registering ${server_name} with Claude CLI...${NC}"
        if [ "$server_name" = "tavily" ]; then
            claude mcp add --name "tavily-search" http://localhost:3000 > /dev/null 2>&1
        elif [ "$server_name" = "firecrawl" ]; then
            claude mcp add --name "firecrawl-web" http://localhost:3333 > /dev/null 2>&1
        elif [ "$server_name" = "openrouter" ]; then
            claude mcp add --name "openrouter-ai" http://localhost:3001 > /dev/null 2>&1
        fi
        echo -e "${GREEN}${server_name} registered with Claude CLI${NC}"
    fi
}

# Stop a specific MCP server
stop_server() {
    local server_name="$1"
    
    echo -e "${BLUE}Stopping ${server_name} MCP server...${NC}"
    
    # Get the PID for this server
    local pid
    pid=$(grep "^${server_name}:" "$PROCESS_FILE" 2>/dev/null | cut -d: -f2)
    
    if [ -n "$pid" ]; then
        # Kill the process
        kill -9 "$pid" 2>/dev/null || true
        
        # Remove the entry from the process file
        grep -v "^${server_name}:" "$PROCESS_FILE" > "$PROCESS_FILE.tmp" 2>/dev/null || true
        mv "$PROCESS_FILE.tmp" "$PROCESS_FILE" 2>/dev/null || true
        
        echo -e "${GREEN}${server_name} MCP server stopped${NC}"
    else
        echo -e "${YELLOW}No running process found for ${server_name}${NC}"
    fi
    
    # Unregister the server from Claude CLI
    if command -v claude &> /dev/null; then
        echo -e "${BLUE}Unregistering ${server_name} from Claude CLI...${NC}"
        if [ "$server_name" = "tavily" ]; then
            claude mcp remove --name "tavily-search" > /dev/null 2>&1 || true
        elif [ "$server_name" = "firecrawl" ]; then
            claude mcp remove --name "firecrawl-web" > /dev/null 2>&1 || true
        elif [ "$server_name" = "openrouter" ]; then
            claude mcp remove --name "openrouter-ai" > /dev/null 2>&1 || true
        fi
        echo -e "${GREEN}${server_name} unregistered from Claude CLI${NC}"
    fi
}

# Start all MCP servers
start_all_servers() {
    echo -e "${BOLD}Starting all MCP servers...${NC}"
    
    # Initialize process file
    rm -f "$PROCESS_FILE"
    touch "$PROCESS_FILE"
    
    # Start each server
    for server in $DEFAULT_SERVERS; do
        start_server "$server"
    done
    
    echo -e "${GREEN}All servers started successfully.${NC}"
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
    
    # Check if process file exists
    if [ ! -f "$PROCESS_FILE" ]; then
        echo -e "${YELLOW}No running MCP servers found.${NC}"
        return
    fi
    
    # Check each server
    while read -r line; do
        if [ -n "$line" ]; then
            local server_name pid status
            server_name=$(echo "$line" | cut -d: -f1)
            pid=$(echo "$line" | cut -d: -f2)
            
            # Check if process is running
            if ps -p "$pid" > /dev/null 2>&1; then
                status="${GREEN}Running${NC}"
            else
                status="${RED}Not Running${NC}"
            fi
            
            printf "%-15s PID: %-10s Status: %b\n" "$server_name" "$pid" "$status"
        fi
    done < "$PROCESS_FILE"
    
    # Check Claude MCP list
    if command -v claude &> /dev/null; then
        echo -e "\n${BOLD}Claude MCP Servers:${NC}"
        claude mcp list || echo -e "${YELLOW}Failed to get Claude MCP list${NC}"
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
        
        for server in $DEFAULT_SERVERS; do
            local log_file="$LOG_DIR/${server}.log"
            
            if [ -f "$log_file" ]; then
                echo -e "${BOLD}=== ${server} ====${NC}"
                tail -n 20 "$log_file"
                echo -e "\n"
            fi
        done
        
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
        echo "Default MCP ports:"
        # Check default ports
        if command -v nc &> /dev/null; then
            echo "Tavily (3000): $(nc -z localhost 3000 2>/dev/null && echo "Open" || echo "Closed")"
            echo "Firecrawl (3333): $(nc -z localhost 3333 2>/dev/null && echo "Open" || echo "Closed")"
            echo "OpenRouter (3001): $(nc -z localhost 3001 2>/dev/null && echo "Open" || echo "Closed")"
        else
            echo "Unable to check ports (nc command not available)"
        fi
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
        for server in $DEFAULT_SERVERS; do
            local log_file="$LOG_DIR/${server}.log"
            
            if [ -f "$log_file" ]; then
                echo "=== $server ==="
                tail -n 10 "$log_file"
                echo ""
            else
                echo "No log file for $server"
            fi
        done
        
    } > "$DIAGNOSTIC_FILE"
    
    echo -e "${GREEN}Diagnostics complete.${NC}"
    echo -e "Diagnostic report saved to: ${DIAGNOSTIC_FILE}"
    echo -e "Run ${BOLD}cat ${DIAGNOSTIC_FILE}${NC} to view the full report."
}

# List available servers from Smithery
list_servers() {
    echo -e "${BOLD}Available MCP Servers from Smithery:${NC}"
    
    # Query the Smithery Registry API
    local response
    response=$(curl -s -H "Authorization: Bearer $SMITHERY_API_KEY" \
        "https://registry.smithery.ai/servers")
    
    # Parse and display the results
    if command -v jq &> /dev/null; then
        # Use jq to parse the JSON response
        echo "$response" | jq -r '.data[] | "- \(.name): \(.description)"'
    else
        # Fallback without jq
        echo "Server list retrieved. View the raw response at $LOG_DIR/smithery_servers.json"
        echo "$response" > "$LOG_DIR/smithery_servers.json"
    fi
}

# Add a server from Smithery
add_server() {
    local server_name="$1"
    
    if [ -z "$server_name" ]; then
        echo -e "${RED}Error: No server name provided.${NC}"
        echo -e "Usage: ./mcp_manager.sh add <server_name>"
        return 1
    fi
    
    echo -e "${BOLD}Adding ${server_name} MCP server from Smithery:${NC}"
    
    # Fetch server information from Smithery
    fetch_server_info "$server_name"
    
    # Add to default servers list
    if ! grep -q "$server_name" <<< "$DEFAULT_SERVERS"; then
        DEFAULT_SERVERS="$DEFAULT_SERVERS $server_name"
        echo "DEFAULT_SERVERS=\"$DEFAULT_SERVERS\"" > "$CONFIG_FILE"
        echo -e "${GREEN}Added ${server_name} to managed servers.${NC}"
    fi
    
    # Suggest API key needed
    echo -e "${YELLOW}Note: Add ${server_name^^}_API_KEY to your .env file if required.${NC}"
    
    # Option to start the server immediately
    read -r -p "Start this server now? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        start_server "$server_name"
    fi
}

# Remove a server
remove_server() {
    local server_name="$1"
    
    if [ -z "$server_name" ]; then
        echo -e "${RED}Error: No server name provided.${NC}"
        echo -e "Usage: ./mcp_manager.sh remove <server_name>"
        return 1
    fi
    
    echo -e "${BOLD}Removing ${server_name} MCP server:${NC}"
    
    # Stop the server if it's running
    stop_server "$server_name"
    
    # Remove from default servers list
    DEFAULT_SERVERS=$(echo "$DEFAULT_SERVERS" | sed "s/\b$server_name\b//g" | tr -s ' ')
    echo "DEFAULT_SERVERS=\"$DEFAULT_SERVERS\"" > "$CONFIG_FILE"
    
    # Remove configuration
    rm -f "$SERVER_CONFIG_DIR/${server_name}.json"
    
    echo -e "${GREEN}Removed ${server_name} from managed servers.${NC}"
}

# Print usage information
print_usage() {
    echo -e "${BOLD}MCP Server Manager${NC}"
    echo -e "A utility for managing Model Context Protocol (MCP) servers."
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
    echo -e "  ${GREEN}list${NC}            List available servers from Smithery"
    echo -e "  ${GREEN}add${NC} <server>    Add a new server from Smithery"
    echo -e "  ${GREEN}remove${NC} <server> Remove a server"
    echo -e "  ${GREEN}help${NC}            Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ./mcp_manager.sh start       # Start all servers"
    echo -e "  ./mcp_manager.sh logs tavily # View tavily server logs"
    echo -e "  ./mcp_manager.sh add my-tool # Add a new server 'my-tool'"
}

# Load saved configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Main function to handle commands
main() {
    local command="$1"
    shift
    
    # If no command provided, use "help"
    if [ -z "$command" ]; then
        command="help"
    fi
    
    # Check requirements first
    if [ "$command" != "help" ]; then
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
        list)
            list_servers
            ;;
        add)
            add_server "$1"
            ;;
        remove)
            remove_server "$1"
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