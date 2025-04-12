# MCP Servers Directory

This directory contains implementations of MCP servers for different services.

## Available MCP Servers

- `tavily/` - Tavily search API integration

## Adding a New MCP Server

### Step-by-Step Guide

1. **Create a directory** for your new service:
   ```bash
   mkdir -p new_service
   ```

2. **Implement your MCP server**:
   - Create a main server script (e.g., `new_service_mcp.py`)
   - Make it executable: `chmod +x new_service_mcp.py`
   - Add a configuration file (`new_service_mcp_config.json`)
   - Include health and MCP endpoints

3. **Configure API key access**:
   - Design your server to read API keys from environment variables
   - Example in Python:
     ```python
     api_key = os.environ.get("NEW_SERVICE_API_KEY")
     if not api_key:
         raise ValueError("NEW_SERVICE_API_KEY environment variable is required")
     ```

4. **Register the server** in `../start_all_mcp_servers.sh`:
   ```bash
   # Open the start script
   nano ../start_all_mcp_servers.sh
   
   # Add your server to the MCP_SERVERS array
   # Format: name|script_path|port|api_key_name
   declare -a MCP_SERVERS=(
     "tavily|./servers/tavily/tavily_mcp.py|5001|TAVILY_API_KEY"
     "new_service|./servers/new_service/new_service_mcp.py|5011|NEW_SERVICE_API_KEY"
   )
   ```

5. **Add API key placeholder** to `../.env.template`:
   ```bash
   # Open the template file
   nano ../.env.template
   
   # Add your API key placeholder
   NEW_SERVICE_API_KEY=your_new_service_api_key_here
   ```

6. **Add your actual API key** to your `.env` file:
   ```bash
   # Open your .env file
   nano ../.env
   
   # Add your actual API key 
   NEW_SERVICE_API_KEY=your_actual_api_key_here
   ```

The start script will automatically load your API key from the `.env` file and make it available to your server as an environment variable.

### Port Allocation Strategy

To avoid port collisions, we use the following port allocation strategy:

- Port 5000 is reserved for system use
- Each service gets its own port range:
  - Tavily: 5001-5009
  - Service2: 5011-5019
  - Service3: 5021-5029
  - etc.

The numbering scheme has logic to it:
- First digit after 5 indicates the service (0=system, 1=Tavily, 2=Service2, etc.)
- Last digit allows for multiple instances of the same service if needed

When adding a new service, pick the next available port range. This allows each service to have multiple instances or variations if needed.

## Implementation Guidelines

### Required Components

Each MCP server implementation should include:

1. **Server Script** with:
   - Self-management of dependencies (recommended)
   - Environment variable handling for API keys
   - Required endpoints:
     - `/mcp` - Main MCP-compliant endpoint
     - `/health` - Health check endpoint
     - `/mcp-config` - Configuration endpoint

2. **Configuration File** (`*_mcp_config.json`) with:
   - Tool name (prefixed with "mcp__")
   - Description
   - Input schema (parameters the tool accepts)
   - Output schema (response structure)
   - Authentication details
   - Usage guidelines

### API Key Handling

Best practices for API key management:

1. **Never hardcode API keys** in your code or configuration files
2. **Use environment variables** to access API keys:
   ```python
   import os
   
   api_key = os.environ.get("YOUR_SERVICE_API_KEY")
   if not api_key:
       raise ValueError("YOUR_SERVICE_API_KEY environment variable is required")
   ```
3. **Document required API keys** in your README
4. **Add placeholder entries** to the `.env.template` file

### Reference Implementation

The `tavily/` directory contains a complete reference implementation that you can use as a starting point:

- `tavily_mcp.py` - Server implementation with dependency management
- `tavily_mcp_config.json` - MCP tool configuration

Use this as a template for creating your own MCP servers.