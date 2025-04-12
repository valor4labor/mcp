#!/bin/bash
# Script to start Tavily MCP server and register it with Claude Code

# Check if TAVILY_API_KEY is set
if [ -z "$TAVILY_API_KEY" ]; then
  echo "Error: TAVILY_API_KEY environment variable is not set"
  echo "Please set it with: export TAVILY_API_KEY=your-api-key"
  exit 1
fi

# Start the MCP server in the background
echo "Starting Tavily MCP server..."
cd "$(dirname "$0")"
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