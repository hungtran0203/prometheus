#!/usr/bin/env python3
"""
Model Context Protocol (MCP) Context Handler
Manages context switching and maintenance for AI model interactions
"""

import os
import yaml
import json
from typing import Dict, List, Optional, Any
from pathlib import Path

class ContextHandler:
    """Handles context management for MCP"""
    
    def __init__(self, config_path: str = "mcp/config/mcp.yaml"):
        """Initialize the context handler with configuration"""
        self.config_path = config_path
        self.config = self._load_config()
        self.current_context = self.config["contexts"]["default"]
        self.context_history = []
        self.context_data = {}
        
    def _load_config(self) -> Dict[str, Any]:
        """Load MCP configuration from YAML file"""
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def get_available_contexts(self) -> List[str]:
        """Get list of available contexts"""
        return [ctx["name"] for ctx in self.config["contexts"]["available"]]
    
    def switch_context(self, context_name: str) -> bool:
        """Switch to a different context"""
        if context_name not in self.get_available_contexts():
            return False
        
        # Save current context to history
        if self.current_context:
            self.context_history.append(self.current_context)
        
        self.current_context = context_name
        return True
    
    def get_context_config(self, context_name: Optional[str] = None) -> Dict[str, Any]:
        """Get configuration for a specific context"""
        context_name = context_name or self.current_context
        for ctx in self.config["contexts"]["available"]:
            if ctx["name"] == context_name:
                return ctx
        return {}
    
    def add_context_data(self, key: str, value: Any) -> None:
        """Add data to current context"""
        if self.current_context not in self.context_data:
            self.context_data[self.current_context] = {}
        self.context_data[self.current_context][key] = value
    
    def get_context_data(self, key: str) -> Optional[Any]:
        """Get data from current context"""
        return self.context_data.get(self.current_context, {}).get(key)
    
    def clear_context_data(self) -> None:
        """Clear all data for current context"""
        if self.current_context in self.context_data:
            self.context_data[self.current_context] = {}
    
    def get_context_prompt(self) -> str:
        """Get the prompt template for current context"""
        context_config = self.get_context_config()
        prompt_name = context_config.get("prompt", self.config["prompts"]["default"])
        
        prompt_path = Path("mcp/prompts") / f"{prompt_name}.md"
        if not prompt_path.exists():
            return ""
        
        with open(prompt_path, 'r') as f:
            return f.read()
    
    def export_context(self, filepath: str) -> None:
        """Export current context state to file"""
        context_state = {
            "current_context": self.current_context,
            "context_history": self.context_history,
            "context_data": self.context_data
        }
        
        with open(filepath, 'w') as f:
            json.dump(context_state, f, indent=2)
    
    def import_context(self, filepath: str) -> bool:
        """Import context state from file"""
        try:
            with open(filepath, 'r') as f:
                context_state = json.load(f)
            
            self.current_context = context_state.get("current_context")
            self.context_history = context_state.get("context_history", [])
            self.context_data = context_state.get("context_data", {})
            return True
        except Exception:
            return False

if __name__ == "__main__":
    # Example usage
    handler = ContextHandler()
    print(f"Available contexts: {handler.get_available_contexts()}")
    print(f"Current context: {handler.current_context}")
    print(f"Context prompt:\n{handler.get_context_prompt()}") 