#!/usr/bin/env python3
"""
Model Context Protocol (MCP) Main Interface
Integrates context and model handlers for AI model operations
"""

import os
import yaml
import json
from typing import Dict, List, Optional, Any
from pathlib import Path
from handlers.context_handler import ContextHandler
from handlers.model_handler import ModelHandler

class MCP:
    """Main interface for Model Context Protocol"""
    
    def __init__(self, config_path: str = "mcp/config/mcp.yaml"):
        """Initialize MCP with configuration"""
        self.config_path = config_path
        self.config = self._load_config()
        self.context_handler = ContextHandler(config_path)
        self.model_handler = ModelHandler(config_path)
        self.interaction_history = []
        
    def _load_config(self) -> Dict[str, Any]:
        """Load MCP configuration from YAML file"""
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def switch_context(self, context_name: str) -> bool:
        """Switch to a different context"""
        return self.context_handler.switch_context(context_name)
    
    def switch_model(self, model_name: str) -> bool:
        """Switch to a different model"""
        return self.model_handler.switch_model(model_name)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """Generate a response using current context and model"""
        # Get context prompt
        context_prompt = self.context_handler.get_context_prompt()
        
        # Combine prompts
        full_prompt = f"{context_prompt}\n\nUser: {prompt}"
        
        # Generate response
        response = self.model_handler.generate_response(full_prompt, **kwargs)
        
        # Record interaction
        self.interaction_history.append({
            "context": self.context_handler.current_context,
            "model": self.model_handler.current_model,
            "prompt": prompt,
            "response": response
        })
        
        return response
    
    def add_context_data(self, key: str, value: Any) -> None:
        """Add data to current context"""
        self.context_handler.add_context_data(key, value)
    
    def get_context_data(self, key: str) -> Optional[Any]:
        """Get data from current context"""
        return self.context_handler.get_context_data(key)
    
    def add_model_data(self, key: str, value: Any) -> None:
        """Add data for current model"""
        self.model_handler.add_model_data(key, value)
    
    def get_model_data(self, key: str) -> Optional[Any]:
        """Get data for current model"""
        return self.model_handler.get_model_data(key)
    
    def export_state(self, filepath: str) -> None:
        """Export current MCP state"""
        state = {
            "context": {
                "current": self.context_handler.current_context,
                "history": self.context_handler.context_history,
                "data": self.context_handler.context_data
            },
            "model": {
                "current": self.model_handler.current_model,
                "history": self.model_handler.model_history,
                "data": self.model_handler.model_data
            },
            "interactions": self.interaction_history
        }
        
        with open(filepath, 'w') as f:
            json.dump(state, f, indent=2)
    
    def import_state(self, filepath: str) -> bool:
        """Import MCP state"""
        try:
            with open(filepath, 'r') as f:
                state = json.load(f)
            
            # Import context state
            self.context_handler.current_context = state["context"]["current"]
            self.context_handler.context_history = state["context"]["history"]
            self.context_handler.context_data = state["context"]["data"]
            
            # Import model state
            self.model_handler.current_model = state["model"]["current"]
            self.model_handler.model_history = state["model"]["history"]
            self.model_handler.model_data = state["model"]["data"]
            
            # Import interaction history
            self.interaction_history = state["interactions"]
            
            return True
        except Exception:
            return False
    
    def get_available_contexts(self) -> List[str]:
        """Get list of available contexts"""
        return self.context_handler.get_available_contexts()
    
    def get_available_models(self) -> List[str]:
        """Get list of available models"""
        return self.model_handler.get_available_models()
    
    def get_current_state(self) -> Dict[str, Any]:
        """Get current MCP state"""
        return {
            "context": {
                "current": self.context_handler.current_context,
                "config": self.context_handler.get_context_config()
            },
            "model": {
                "current": self.model_handler.current_model,
                "config": self.model_handler.get_model_config()
            }
        }

if __name__ == "__main__":
    # Example usage
    mcp = MCP()
    print(f"Available contexts: {mcp.get_available_contexts()}")
    print(f"Available models: {mcp.get_available_models()}")
    print(f"Current state: {mcp.get_current_state()}")
    
    # Test response generation
    response = mcp.generate_response("Hello, how are you?")
    print(f"Test response: {response}") 