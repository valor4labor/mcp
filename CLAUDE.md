# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Run tests**: `./test_mcp_servers.sh` (requires venv with dependencies)
- **Run integration tests**: `source venv/bin/activate && ./test_mcp_servers.sh`
- **Run unit tests**: `source venv/bin/activate && pytest tests/`
- **Run single test**: `source venv/bin/activate && pytest tests/tavily/test_tavily_mcp.py::TestTavilyMCP::test_search_basic`
- **Start all MCP servers**: `./start_all_mcp_servers.sh`
- **Start Tavily server only**: `./load_tavily_mcp.sh`

## Style Guidelines

- **Python**: Follow PEP 8 conventions (spaces not tabs, 4-space indentation)
- **Imports**: Group standard library, third-party, and local imports with blank lines between groups
- **Typing**: Use type hints for function parameters and return values
- **Naming**: Use snake_case for functions/variables, PascalCase for classes
- **Error handling**: Catch specific exceptions with informative error messages
- **Documentation**: Include docstrings for all functions, classes, and modules
- **API keys**: Never hardcode API keys; always use environment variables
- **Port allocation**: Use port ranges as documented (eg. Tavily: 5001-5009)
- **Bash scripts**: Make all scripts executable with shebang line and error handling