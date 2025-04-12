# MCP Server Tests

This directory contains tests for MCP servers.

## Test Structure

- `tavily/` - Tests for Tavily MCP server
  - `test_tavily_mcp.py` - Unit tests for Tavily MCP functionality

## Running Tests

### Shell-based Integration Tests

Run the script to test the MCP servers in an integrated way:

```bash
./test_mcp_servers.sh
```

This will:
1. Set up dependencies and virtual environments if needed
2. Start each MCP server
3. Test the health endpoint
4. Test the MCP configuration endpoint
5. Test the MCP endpoint with a test query
6. Shut down all servers

#### Setup for Testing

For best results, prepare a testing environment:

```bash
# Create a virtual environment
uv venv venv

# Activate the environment
source venv/bin/activate

# Install test dependencies
uv pip install tavily-python requests pytest
```

#### Troubleshooting

If you encounter issues:

1. **API Key Problems**:
   ```
   Error: Tavily API key not provided
   ```
   Make sure your `.env` file contains the required API keys:
   ```
   TAVILY_API_KEY=your_actual_key_here
   ```

2. **Port Already in Use**:
   If you see an error about the port being in use, ensure no other MCP servers are running.
   ```bash
   # Check if the port is in use
   lsof -i:5001
   
   # If needed, kill the process
   kill <PID>
   ```

3. **Dependency Issues**:
   The test script passes the API key directly to the server script, but you might need to install dependencies:
   ```bash
   uv pip install tavily-python requests
   ```

### Python Unit Tests

Run Python unit tests using pytest or unittest:

```bash
# Using pytest (recommended)
pytest tests/

# Or for a specific server
pytest tests/tavily/

# Using unittest
python -m unittest discover tests
```

## Adding Tests for New Servers

When adding a new MCP server:

1. Create a new directory: `tests/server_name/`
2. Add unit tests: `tests/server_name/test_server_name_mcp.py`
3. Add to the shell test script by adding a new test section in `test_mcp_servers.sh`

## Test Requirements

These tests require:
- Python 3.8+
- pytest (optional, for better test running)
- tavily-python (for Tavily tests)
- Valid API keys in your `.env` file