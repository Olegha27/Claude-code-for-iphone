#!/usr/bin/env python3
"""
Claude Code Mobile Backend
Runs the FastAPI server with WebSocket support for iOS app
"""
import os
import uvicorn
from mobile_api import create_app, app
from dotenv import load_dotenv

load_dotenv()

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8082"))
    host = os.getenv("HOST", "0.0.0.0")

    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info",
        reload=True  # Enable auto-reload during development
    )
