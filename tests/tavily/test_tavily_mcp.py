#!/usr/bin/env python3
"""
Unit tests for the Tavily MCP server.
"""

import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the parent directory to the path so we can import the server module
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../servers/tavily')))
from tavily_mcp import TavilyMCP


class TestTavilyMCP(unittest.TestCase):
    """Tests for the TavilyMCP class."""

    def setUp(self):
        """Set up test environment."""
        self.api_key = "test_api_key"

    @patch('tavily_mcp.TavilyClient')
    def test_search_basic(self, mock_tavily_client):
        """Test basic search functionality."""
        # Set up mock
        mock_instance = mock_tavily_client.return_value
        mock_instance.search.return_value = {
            "query": "test query",
            "results": [
                {
                    "title": "Test Result",
                    "url": "https://example.com/test",
                    "content": "This is a test result content",
                    "score": 0.95
                }
            ]
        }

        # Create instance with test API key
        mcp = TavilyMCP(api_key=self.api_key)
        
        # Call the method
        result = mcp.search("test query")
        
        # Verify result
        self.assertIn("results", result)
        self.assertEqual(len(result["results"]), 1)
        self.assertEqual(result["results"][0]["title"], "Test Result")
        
        # Verify method was called with correct parameters
        mock_instance.search.assert_called_once_with(
            query="test query",
            max_results=10,
            search_depth="basic"
        )

    @patch('tavily_mcp.TavilyClient')
    def test_search_with_parameters(self, mock_tavily_client):
        """Test search with custom parameters."""
        # Set up mock
        mock_instance = mock_tavily_client.return_value
        mock_instance.search.return_value = {
            "query": "test query",
            "results": []
        }

        # Create instance
        mcp = TavilyMCP(api_key=self.api_key)
        
        # Call the method with custom parameters
        mcp.search("test query", max_results=5, search_depth="advanced")
        
        # Verify method was called with correct parameters
        mock_instance.search.assert_called_once_with(
            query="test query",
            max_results=5,
            search_depth="advanced"
        )

    def test_missing_api_key(self):
        """Test behavior when API key is missing."""
        # Test with None
        with self.assertRaises(ValueError):
            TavilyMCP(api_key=None)
        
        # Test with empty string
        with self.assertRaises(ValueError):
            TavilyMCP(api_key="")


if __name__ == '__main__':
    unittest.main()