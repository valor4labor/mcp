# MCP Server Management System

This repository provides a comprehensive system for managing Multiple Claude Protocol (MCP) servers that extend Claude's capabilities with external tools.

## Overview

The MCP Server Management System includes:

- **Complete Server Management**: Start, stop, and monitor multiple MCP servers
- **Easy Configuration**: Simple templates for API keys and Claude config
- **One-Click Setup**: Initialize your environment with a single command
- **Ready-to-Use Components**: Pre-configured Tavily search MCP server

## Getting Started

### Prerequisites

- Python 3.8 or higher
- `uv` package manager (`pip install uv`)
- API keys for desired services (e.g., [Tavily](https://tavily.com))

### Quick Setup

1. **Run the setup script** to initialize your environment:

```bash
./setup_mcp_env.sh
```

This will:
- Create a `.env` file from the template
- Set up Claude's config directory and config.json
- Check for the uv package manager
- Provide usage instructions

2. **Edit the `.env` file** to add your API keys:

```bash
# Open the .env file in your preferred editor
nano .env

# Add your API keys (without quotes)
TAVILY_API_KEY=your_actual_key_here
```

The system uses this `.env` file to securely store your API keys, which are loaded when starting the MCP servers. This approach keeps sensitive credentials separate from the code.

3. **Start the MCP servers**:

```bash
# Start all configured MCP servers
./start_all_mcp_servers.sh

# Or start just the Tavily search server
./load_tavily_mcp.sh
```

The script will verify that all required API keys are properly set before starting each server.

### Manual Setup

If you prefer manual setup, you can:

1. Copy `.env.template` to `.env` and add your API keys
2. Set your Tavily API key directly:
   ```bash
   export TAVILY_API_KEY="your-tavily-api-key"
   ```
3. Run the server manually:
   ```bash
   ./tavily_mcp.py
   ```

Or with custom settings:

```bash
./tavily_mcp.py --host 0.0.0.0 --port 8080 --api-key your-tavily-api-key
```

## Usage with Claude Code

### Using with Default Config

If you've set up the config.json file, you can use Claude Code without any extra flags:

```bash
claude-code "Who won the latest F1 race?"
```

### Using with Command Line Flag

Or specify the MCP tool directly:

```bash
claude-code --mcp-tool="http://localhost:5000/mcp" "Who won the latest F1 race?"
```

## Available MCP Servers

### Tavily Search MCP

The included Tavily search MCP server exposes several endpoints:

#### 1. MCP Endpoint

```
POST /mcp
Content-Type: application/json

{
  "inputs": {
    "query": "latest AI developments",
    "max_results": 5,
    "search_depth": "advanced"
  }
}
```

#### 2. Direct Search Endpoint

```
POST /search
Content-Type: application/json

{
  "query": "latest AI developments",
  "max_results": 5,
  "search_depth": "advanced"
}
```

#### 3. Health Check

```
GET /health
```

#### 4. MCP Configuration

```
GET /mcp-config
```

## Adding New MCP Servers

To add a new MCP server to the system:

1. **Create a server directory and implementation**:
   ```bash
   # Create a directory for your new service
   mkdir -p servers/new_service
   
   # Implement your MCP server in this directory
   # - Main server script (e.g., new_service_mcp.py)
   # - Configuration file (e.g., new_service_mcp_config.json)
   ```

2. **Update server configuration** in `start_all_mcp_servers.sh`:
   ```bash
   # Open the start_all_mcp_servers.sh file
   nano start_all_mcp_servers.sh
   
   # Add your server to the MCP_SERVERS array
   # Format: name|script_path|port|api_key_name
   declare -a MCP_SERVERS=(
     "tavily|./servers/tavily/tavily_mcp.py|5001|TAVILY_API_KEY"
     "new_service|./servers/new_service/new_service_mcp.py|5011|NEW_SERVICE_API_KEY"
   )
   ```

3. **Add API key to `.env.template`** for others who will install this system:
   ```bash
   # Open the .env.template file
   nano .env.template
   
   # Add your API key placeholder
   NEW_SERVICE_API_KEY=your_new_service_api_key_here
   ```

4. **Add the API key to your own `.env` file**:
   ```bash
   # Open your .env file
   nano .env
   
   # Add your actual API key
   NEW_SERVICE_API_KEY=your_actual_api_key_here
   ```

The system will automatically load your API key from the `.env` file when starting the server.

### Port Allocation Strategy

To avoid port collisions between MCP servers, we use this port allocation strategy:

- Port 5000 is reserved for system use
- Each service gets its own port range (9 ports each):
  - Tavily: 5001-5009
  - Service2: 5011-5019
  - Service3: 5021-5029
  - etc.

The numbering scheme is structured as follows:
- First digit after 5 indicates the service (0=system, 1=Tavily, 2=Service2, etc.)
- Last digit allows for multiple instances of the same service if needed

This approach allows for future expansion and multiple instances of the same service to run on different ports if needed.

Example directory structure for a new server:
```
servers/
├── tavily/            # Existing Tavily implementation
│   ├── tavily_mcp.py
│   └── tavily_mcp_config.json
└── new_service/       # New service implementation
    ├── new_service_mcp.py
    └── new_service_mcp_config.json
```

## System Components

### Scripts

- `start_all_mcp_servers.sh` - Main control script that:
  - Starts all configured MCP servers with their API keys
  - Manages server processes and tracks PIDs
  - Shows Claude Code usage instructions
  - Handles clean shutdown of all servers

- `setup_mcp_env.sh` - One-click environment setup that:
  - Creates .env file from template
  - Sets up Claude's config directory and config.json
  - Checks for uv package manager
  - Provides usage instructions

- `load_tavily_mcp.sh` - Standalone script for just the Tavily server

### Configuration Files

- `.env.template` - Template for API keys
- `config_template.json` - Template for Claude's ~/.claude/config.json
- `servers/tavily/tavily_mcp_config.json` - MCP tool configuration for Tavily

### Directory Structure

```
mcp/
├── .env.template
├── config_template.json
├── load_tavily_mcp.sh
├── README.md
├── servers/
│   └── tavily/
│       ├── tavily_mcp.py
│       └── tavily_mcp_config.json
├── setup_mcp_env.sh
└── start_all_mcp_servers.sh
```

## Example Response from Tavily

```json
{
  "results": [
    {
      "title": "Latest AI Developments in 2025",
      "url": "https://example.com/ai-news",
      "content": "The AI field has seen significant progress in...",
      "score": 0.95
    },
    ...
  ],
  "query": "latest AI developments",
  "count": 5,
  "search_depth": "advanced"
}
```

## Error Handling

The servers return appropriate HTTP status codes for different error conditions:

- 400: Bad request (missing parameters)
- 401: Unauthorized (invalid API key)
- 429: Too many requests (rate limit exceeded)
- 500: Internal server error

## Security Notes

- API keys are stored as environment variables for security
- The servers do not log or store queries beyond the current request
- Consider running behind a reverse proxy for production use

## License

MIT