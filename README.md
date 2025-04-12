# MCP Server Manager

A streamlined utility for running MCP servers using Smithery's hosted services.

## Overview

MCP Server Manager provides a simple command-line interface to manage Model Context Protocol (MCP) servers that extend Claude's capabilities with:

- **Web Search** via Tavily
- **Web Crawling** via Firecrawl
- **AI Model Access** via OpenRouter
- **Sequential Thinking** for step-by-step reasoning
- **Browser Automation** via Playwright
- **Obsidian Integration** for accessing project management notes and documentation

This utility uses Smithery's hosted versions of these services for maximum reliability and ease of use.

## Prerequisites

- [Node.js v20+](https://nodejs.org/) (required)
- [Claude CLI](https://github.com/anthropics/claude-cli)
- [Smithery account](https://smithery.ai/) and API key
- API keys for each service:
  - [Tavily](https://tavily.com/)
  - [Firecrawl](https://firecrawl.dev/)
  - [OpenRouter](https://openrouter.ai/)

## Installation

### Local Installation

```bash
# Clone the repository
git clone https://github.com/valor4labor/mcp.git
cd mcp

# Make the script executable
chmod +x mcp_manager.sh
```

### Global Installation

```bash
# Install globally with npm
npm install -g git+https://github.com/valor4labor/mcp.git

# Now you can run from anywhere
mcp-manager start
```

## Quick Start

```bash
# 1. Add your API keys to the .env file (create it first if needed)
nano .env

# 2. Start the MCP servers
# For local installation:
./mcp_manager.sh start
# OR for global installation:
mcp-manager start

# 3. In a new terminal, start Claude
claude
```

## Configuration

1. Create a `.env` file with your API keys:

```
# Smithery API Key - Get from https://smithery.ai/ (under your profile)
SMITHERY_API_KEY=your_smithery_key_here

# Tavily API Key - Get from https://tavily.com/
TAVILY_API_KEY=your_tavily_key_here

# Firecrawl API Key - Get from https://firecrawl.dev/
FIRECRAWL_API_KEY=your_firecrawl_key_here

# OpenRouter API Key - Get from https://openrouter.ai/
OPENROUTER_API_KEY=your_openrouter_key_here
```

2. Edit the `mcp_config.json` file as needed to add or remove MCP servers.

## Usage

The manager provides a simple interface to control your MCP servers:

For local installation:
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
```

For global installation:
```bash
# Start all configured servers
mcp-manager start

# Stop all running servers
mcp-manager stop

# Check status of servers
mcp-manager status

# View server logs
mcp-manager logs [server_name]

# Run diagnostics
mcp-manager diagnose
```

### Custom Configuration Directory

For global installations, you can specify a custom configuration directory:

```bash
# Set environment variable for configuration directory
export MCP_CONFIG_DIR=/path/to/your/config

# Run commands
mcp-manager start
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

1. Using Smithery's hosted versions of MCP servers
2. Securely passing your API keys to the appropriate servers
3. Managing server processes and lifecycles
4. Providing diagnostics and troubleshooting

### Idempotent Operations

The MCP Server Manager is designed to be safely run multiple times with the same results:

- **Starting servers**: If a server is already running, it won't start a duplicate
- **Stopping servers**: Only running servers will be stopped
- **Status checks**: Automatically cleans up stale process entries
- **MCP registration**: Prevents duplicate Claude CLI registrations

## Project Management Vault

The Obsidian integration connects to your Project-Management vault, providing Claude with access to documentation for these projects:

- Bee
- DeckFusion
- Django Project Template
- Golden Egg
- PsyOptimal
- Royop
- Sage - Best Kept
- Snowbird #Verkstad
- Yudame Operations

Claude can search, retrieve, and analyze notes from these projects to assist with your development work.

## License

MIT
