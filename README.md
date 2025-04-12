# MCP Server Manager

A streamlined utility for managing Model Context Protocol (MCP) servers for Claude using the Smithery registry.

## Overview

MCP Server Manager provides a simple command-line interface to set up, manage, and troubleshoot MCP servers that extend Claude's capabilities with:

- **Web Search** via Tavily
- **Web Crawling** via Firecrawl
- **AI Model Access** via OpenRouter
- **Other capabilities** via the Smithery registry

## Prerequisites

- [Claude CLI](https://github.com/anthropics/claude-cli)
- [Smithery account](https://smithery.ai/)
- API keys for services you want to use:
  - [Tavily](https://tavily.com/)
  - [Firecrawl](https://firecrawl.dev/)
  - [OpenRouter](https://openrouter.ai/)

## Quick Start

```bash
# 1. Add your API keys to the .env file (create it first if needed)
nano .env

# 2. Start the MCP servers
./mcp_manager.sh start

# 3. In a new terminal, start Claude
claude
```

## Configuration

Create a `.env` file with your API keys:

```
# Smithery API Key - Get from https://smithery.ai/
SMITHERY_API_KEY=your_smithery_key_here

# Tavily API Key - Get from https://tavily.com/
TAVILY_API_KEY=your_tavily_key_here

# Firecrawl API Key - Get from https://firecrawl.dev/
FIRECRAWL_API_KEY=your_firecrawl_key_here

# OpenRouter API Key - Get from https://openrouter.ai/
OPENROUTER_API_KEY=your_openrouter_key_here
```

## Usage

The manager provides a simple interface to control your MCP servers:

```bash
# Start all configured servers
./mcp_manager.sh start

# Stop all running servers
./mcp_manager.sh stop

# Check status of servers
./mcp_manager.sh status

# View server logs
./mcp_manager.sh logs [server_name]

# Run diagnostics
./mcp_manager.sh diagnose

# List available servers from Smithery
./mcp_manager.sh list

# Add a new server from Smithery
./mcp_manager.sh add <server_name>

# Remove a server
./mcp_manager.sh remove <server_name>
```

## Using MCP Tools in Claude

When Claude starts, verify available MCP tools by typing:

```
/mcp
```

You should see your configured tools like "tavily-search", "firecrawl-web", and "openrouter-ai" in the list.

## Troubleshooting

If you encounter issues:

1. **Check server status**:
   ```bash
   ./mcp_manager.sh status
   ```

2. **Verify API keys**:
   Make sure all API keys in your `.env` file are valid and correctly formatted.

3. **Run diagnostics**:
   ```bash
   ./mcp_manager.sh diagnose
   ```

4. **Check logs**:
   ```bash
   ./mcp_manager.sh logs
   ```

5. **Use Claude debug mode**:
   ```bash
   claude --mcp-debug
   ```

## How It Works

This utility simplifies managing MCP servers by:

1. Utilizing the Smithery registry to discover and launch vendor-maintained MCP servers
2. Securely passing your API keys to the appropriate servers
3. Managing server processes and lifecycles
4. Providing diagnostics and troubleshooting

## License

MIT