# MCP Server Management System

This repository provides a comprehensive system for managing Multiple Claude Protocol (MCP) servers that extend Claude's capabilities with external tools.

[![Build Status](https://img.shields.io/badge/tests-passing-brightgreen.svg)](https://github.com/your-repo/mcp)

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
- For testing: `pip install pytest requests tavily-python`

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

### When to Use Claude Code with MCP Tools

Claude Code with MCP tools gives you powerful capabilities beyond the standard Claude model:

- **Real-time Information Access**: Get up-to-date information about current events, news, and facts beyond Claude's knowledge cutoff
- **Web Research**: Search the web for specific information, sources, or references
- **Content Verification**: Fact-check information or find supporting evidence
- **Technical Research**: Look up documentation, code examples, or technical specifications

Some examples of when to use Claude Code with MCP tools:

```
# Research questions
claude "What are the latest developments in AI regulation in 2025?"

# Fact-checking
claude "Who is currently the CEO of Apple?"

# Technical assistance
claude "Find best practices for handling async operations in React"

# Current events
claude "What were the results of yesterday's F1 race?"
```

### Using MCP with Claude Code

Our scripts now handle two important aspects of using MCP tools:

1. **Registration**: The scripts register the MCP servers with Claude so they show up in the tool list
2. **Running**: The scripts start the MCP servers which must remain running while you use Claude

#### Recommended Workflow

There are two ways to use MCP tools with Claude:

##### Option 1: Use Claude's MCP server manager (Recommended)

1. **Register** the MCP servers with Claude:
   ```bash
   # Register all MCP servers
   ./start_all_mcp_servers.sh --register-only
   ```

2. **Start Claude's MCP server manager**:
   ```bash
   # This will start and manage all registered MCP servers
   claude mcp serve
   ```

3. **In a new terminal window**, run Claude:
   ```bash
   # Connect to the running servers
   claude
   ```

##### Option 2: Manual server management

1. **First Terminal**: Run the server script and **leave it running**
   ```bash
   # Start the MCP server and keep this terminal open
   ./start_all_mcp_servers.sh
   ```

2. **Second Terminal**: Run Claude in a different terminal window
   ```bash
   # In a new terminal window
   claude
   ```

#### Global Registration

The MCP servers are registered with **global scope** and **absolute paths**, which means:

1. They're available in all directories on your system, not just the current project
2. They work correctly regardless of your current working directory
3. You don't need to be in the MCP directory to use them

This makes the MCP tools available globally, but **remember that the server must be running** in another terminal window.

#### MCP Server Management

You can manage your MCP servers with these commands:

```bash
# List all configured servers
claude mcp list

# Get details about a specific server
claude mcp get tavily

# Remove a server
claude mcp remove tavily
```

#### Manual Registration (if needed)

You can manually register an MCP server with Claude using:

```bash
# Basic format (global scope with absolute path)
claude mcp add server-name -e API_KEY=your_key --scope user -- /absolute/path/to/server --port 5001

# Example for Tavily (from the mcp directory)
SCRIPT_PATH="$(realpath ./servers/tavily/tavily_mcp.py)"
claude mcp add tavily -e TAVILY_API_KEY=${TAVILY_API_KEY} --scope user -- "$SCRIPT_PATH" --port 5001
```

The `-e` flag passes environment variables to the MCP server, the `--scope user` flag makes the server available globally across all directories, and the `--` separator marks where the server command begins. All arguments after the `--` are passed to the server.

### Using MCP in Claude Code

There are two parts to using the MCP tools:

1. **Registering the MCP server** (which our scripts do automatically)
2. **Running the MCP server** (which must be active when you use Claude)

#### Important: Always Run the MCP Server First

Before using Claude, make sure the MCP server is running in a terminal window:

```bash
# Keep this terminal window open while using Claude
./start_all_mcp_servers.sh
```

Then, in a separate terminal window:

```bash
# This will use the registered and running MCP server
claude "Who won the latest F1 race?"
```

#### Debugging MCP Issues

If you're having issues with MCP, use the `--mcp-debug` flag:

```bash
claude --mcp-debug
```

This will show any connection errors with the MCP servers.

### Troubleshooting MCP Integration

If you're having issues with the MCP tools, check these common problems:

#### 1. "Connection failed" or "MCP server tavily failed"

This usually means the server isn't running. Remember the two-terminal workflow:
- Terminal 1: Run and keep `./start_all_mcp_servers.sh` open (it will automatically stop any existing server instances)
- Terminal 2: Run `claude` commands

#### 2. Server not showing up in `/mcp` list

Check that the server is properly registered:
```bash
claude mcp list
```
You should see "tavily" with an absolute path. If not, re-run the start script.

#### 3. Debug Mode

To see detailed error information:
```bash
claude --mcp-debug
```
This will show connection errors and other issues when you run a query.

#### 4. Verify Server Health

If you suspect the server isn't running correctly, check its health endpoint:
```bash
# In a new terminal
curl http://localhost:5001/health
```
It should return `{"status": "healthy"}`.

#### 5. Port Already in Use

If you get errors about the port being in use, the scripts will now automatically:
1. Detect any processes using the required ports
2. Stop them gracefully before starting the new server
3. Verify the port is free before continuing

This makes it easier to restart the server without manual intervention.

#### 6. Test Query

To verify everything is working, ask a question that requires web search:
```
What is the current weather in New York City? Use the search tool to find real-time information.
```

#### 7. API Key Issues

If the server gives API key errors, check your .env file:
```bash
cat .env | grep TAVILY
```
Make sure the API key is valid and not expired.

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

## Testing

To verify that your MCP servers are working correctly:

```bash
# Create a virtual environment
uv venv venv

# Activate the environment
source venv/bin/activate

# Install test dependencies
uv pip install tavily-python requests pytest

# Run the integration tests
./test_mcp_servers.sh
```

This will test all configured MCP servers, including:
- Health endpoints
- Configuration endpoints
- MCP endpoints with sample queries

For more detailed testing information, see [tests/README.md](tests/README.md).

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

- `test_mcp_servers.sh` - Testing script that:
  - Starts each server in test mode
  - Validates health, config, and MCP endpoints
  - Provides diagnostic information
  - Automatically cleans up after testing

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