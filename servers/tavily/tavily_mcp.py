#!/usr/bin/env python3
"""
Tavily MCP Server - Single file server that acts as a Tavily client.
This script manages its own dependencies using uv.
"""

import os
import sys
import subprocess
import json
from typing import Dict, List, Optional, Any
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("tavily_mcp")

# Required dependencies
DEPENDENCIES = [
    "tavily-python",
    "requests"
]


def ensure_dependencies() -> None:
    """Use uv to install required dependencies if they aren't already installed."""
    try:
        # Check if uv is installed
        subprocess.run(["uv", "--version"], capture_output=True, check=True)
    except (subprocess.SubprocessError, FileNotFoundError):
        logger.error("uv is not installed. Please install it with 'pip install uv'")
        sys.exit(1)
    
    logger.info("Installing dependencies with uv...")
    try:
        # Create a virtual environment if it doesn't exist
        venv_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv")
        if not os.path.exists(venv_dir):
            subprocess.run(["uv", "venv", venv_dir], check=True)
        
        # Install dependencies
        subprocess.run(
            ["uv", "pip", "install"] + DEPENDENCIES,
            check=True,
        )
        logger.info("Dependencies installed successfully")
    except subprocess.SubprocessError as e:
        logger.error(f"Failed to install dependencies: {e}")
        sys.exit(1)


# After ensuring dependencies are installed, import them
ensure_dependencies()

# Now we can safely import these dependencies
import requests
try:
    from tavily import TavilyClient
except ImportError:
    logger.error("Failed to import Tavily client despite installing dependencies")
    sys.exit(1)


class TavilyMCP:
    """Tavily client wrapper for MCP integration."""
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("TAVILY_API_KEY")
        if not self.api_key:
            logger.error("Tavily API key is not provided and not found in environment")
            raise ValueError("Tavily API key is required")
        
        self.client = TavilyClient(api_key=self.api_key)
    
    def search(self, query: str, max_results: int = 10, search_depth: str = "basic") -> Dict[str, Any]:
        """Perform a Tavily search and return results."""
        try:
            response = self.client.search(
                query=query,
                max_results=max_results,
                search_depth=search_depth
            )
            return response
        except Exception as e:
            logger.error(f"Tavily search error: {e}")
            return {"error": str(e)}


class MCPRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the MCP server."""
    
    def __init__(self, *args, tavily_client=None, **kwargs):
        self.tavily_client = tavily_client
        # Using this approach to pass the client to the handler instance
        # The actual initialization happens in the MCPServer class
        super().__init__(*args, **kwargs)
    
    def _send_response(self, status_code: int, data: Dict[str, Any]) -> None:
        """Helper method to send a JSON response."""
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_POST(self) -> None:
        """Handle POST requests."""
        if self.path == "/mcp":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                if content_length == 0:
                    self._send_response(400, {"error": "Empty request body"})
                    return
                
                request_data = json.loads(self.rfile.read(content_length).decode())
                
                # Check for MCP command structure
                if "inputs" not in request_data:
                    self._send_response(400, {"error": "Missing 'inputs' in MCP request"})
                    return
                
                inputs = request_data["inputs"]
                
                # Validate required parameters
                if "query" not in inputs:
                    self._send_response(400, {"error": "Missing 'query' parameter in inputs"})
                    return
                
                # Optional parameters with defaults
                max_results = inputs.get("max_results", 10)
                search_depth = inputs.get("search_depth", "basic")
                
                # Perform search
                results = self.tavily_client.search(
                    query=inputs["query"],
                    max_results=max_results,
                    search_depth=search_depth
                )
                
                # Format response for MCP
                self._send_response(200, {
                    "results": results["results"],
                    "query": results["query"],
                    "count": len(results["results"]),
                    "search_depth": search_depth
                })
            except json.JSONDecodeError:
                self._send_response(400, {"error": "Invalid JSON in request body"})
            except Exception as e:
                logger.error(f"Error processing request: {e}")
                self._send_response(500, {"error": str(e)})
        elif self.path == "/search":
            # Legacy API endpoint
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                if content_length == 0:
                    self._send_response(400, {"error": "Empty request body"})
                    return
                
                request_data = json.loads(self.rfile.read(content_length).decode())
                
                # Validate required parameters
                if "query" not in request_data:
                    self._send_response(400, {"error": "Missing 'query' parameter"})
                    return
                
                # Optional parameters with defaults
                max_results = request_data.get("max_results", 10)
                search_depth = request_data.get("search_depth", "basic")
                
                # Perform search
                results = self.tavily_client.search(
                    query=request_data["query"],
                    max_results=max_results,
                    search_depth=search_depth
                )
                
                self._send_response(200, results)
            except json.JSONDecodeError:
                self._send_response(400, {"error": "Invalid JSON in request body"})
            except Exception as e:
                logger.error(f"Error processing request: {e}")
                self._send_response(500, {"error": str(e)})
        else:
            self._send_response(404, {"error": "Not found"})
    
    def do_GET(self) -> None:
        """Handle GET requests - provides a simple health check endpoint."""
        if self.path == "/health":
            self._send_response(200, {"status": "healthy"})
        elif self.path == "/mcp-config":
            # Serve the MCP configuration
            config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tavily_mcp_config.json")
            try:
                with open(config_path, "r") as f:
                    config = json.load(f)
                self._send_response(200, config)
            except Exception as e:
                logger.error(f"Error serving MCP config: {e}")
                self._send_response(500, {"error": f"Failed to serve MCP config: {str(e)}"})
        else:
            self._send_response(404, {"error": "Not found"})


class MCPServer:
    """Server class that handles Tavily MCP requests."""
    
    def __init__(self, host: str = "localhost", port: int = 5000, api_key: Optional[str] = None):
        self.host = host
        self.port = port
        self.tavily_client = TavilyMCP(api_key=api_key)
        
        # Custom handler class that includes the Tavily client
        handler = lambda *args, **kwargs: MCPRequestHandler(*args, tavily_client=self.tavily_client, **kwargs)
        self.server = HTTPServer((self.host, self.port), handler)
    
    def start(self) -> None:
        """Start the server."""
        logger.info(f"Starting Tavily MCP server on {self.host}:{self.port}")
        try:
            self.server.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server interrupted by user")
        finally:
            self.server.server_close()
            logger.info("Server stopped")


def main() -> None:
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description="Tavily MCP Server")
    parser.add_argument("--host", default="localhost", help="Host to bind the server to")
    parser.add_argument("--port", type=int, default=5000, help="Port to bind the server to")
    parser.add_argument("--api-key", help="Tavily API key (can also be set via TAVILY_API_KEY env var)")
    
    args = parser.parse_args()
    
    api_key = args.api_key or os.environ.get("TAVILY_API_KEY")
    if not api_key:
        logger.error("Tavily API key not provided. Set it with --api-key or TAVILY_API_KEY env var")
        sys.exit(1)
    
    server = MCPServer(host=args.host, port=args.port, api_key=api_key)
    server.start()


if __name__ == "__main__":
    main()