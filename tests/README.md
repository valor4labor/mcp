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
1. Start each MCP server
2. Test the health endpoint
3. Test the MCP configuration endpoint
4. Test the MCP endpoint with a test query
5. Shut down all servers

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