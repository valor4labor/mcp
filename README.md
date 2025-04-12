# MCP Server Management System

This repository provides a system for managing the Tavily MCP server that extends Claude's capabilities with web search.

[![Build Status](https://img.shields.io/badge/tests-passing-brightgreen.svg)](https://github.com/your-repo/mcp)

## The Simple MCP Setup Process

Setting up and using the MCP server requires just three steps:

1. **Setup** - Run the setup script and add your API key
2. **Register & Start** - Register and start the MCP server manager 
3. **Use** - Use Claude with the MCP tool

### Step 1: Setup

Run the setup script to initialize your environment:

```bash
./setup_mcp_env.sh
```

This will:
- Create a `.env` file from the template
- Set up Claude's config directory 
- Check for the uv package manager

Next, edit the `.env` file to add your Tavily API key:

```bash
# Open the .env file in your preferred editor
nano .env

# Add your API key (without quotes)
TAVILY_API_KEY=your_actual_key_here
```

### Step 2: Register & Start

Register the MCP server with Claude and start the server manager:

```bash
# Register the MCP server
./start_all_mcp_servers.sh --register-only

# Start Claude's MCP server manager
claude mcp serve
```

Leave this terminal window open with the server running.

### Step 3: Use

Open a new terminal window and use Claude with the MCP tool:

```bash
# Connect to the running server
claude
```

When Claude starts, you can verify the MCP tool is available by typing:

```
/mcp
```

You should see "tavily" in the list of available tools.

Now you can ask Claude questions that require web search:

```
What are the latest developments in AI regulation in 2025?
```

## When to Use MCP Tools

Use Claude with MCP tools when you need:

- Real-time information beyond Claude's knowledge cutoff
- Web research for specific information or references
- Fact-checking or verification of information
- Current events, news, or recent developments

Example queries:
```
Who is currently the CEO of Apple?
What were the results of yesterday's F1 race?
Find best practices for handling async operations in React
```

## Troubleshooting

If you have issues with the MCP server:

1. Verify the server is running: Keep the `claude mcp serve` terminal window open
2. Check server registration: Run `claude mcp list` to see if "tavily" is listed
3. Check API key: Make sure your Tavily API key is valid and added to the `.env` file
4. Test with debug mode: Run `claude --mcp-debug` to see detailed error information

## License

MIT