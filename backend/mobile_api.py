"""
FastAPI WebSocket server for iOS app
Provides real-time chat and REST endpoints for file operations, commands, and config
"""
import os
import json
import asyncio
from pathlib import Path
from typing import List, Dict, Any, Optional
import subprocess
from datetime import datetime

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psutil

# Pydantic models for request/response
class ChatMessage(BaseModel):
    type: str = "chat"
    message: str

class CommandRequest(BaseModel):
    type: str = "command"
    command: str
    cwd: str = "."

class FileListRequest(BaseModel):
    type: str = "file_list"
    path: str = "."

class FileReadRequest(BaseModel):
    type: str = "file_read"
    path: str

class FileWriteRequest(BaseModel):
    type: str = "file_write"
    path: str
    content: str

class ConfigRequest(BaseModel):
    type: str = "config_get"
    key: Optional[str] = None

# Response models
class MessageResponse(BaseModel):
    type: str
    message: str
    timestamp: datetime

class CommandResponse(BaseModel):
    type: str = "command_result"
    output: str
    exit_code: int
    timestamp: datetime
    error: Optional[str] = None

class FileListResponse(BaseModel):
    type: str = "file_list"
    files: List[Dict[str, Any]]
    timestamp: datetime

class FileContentResponse(BaseModel):
    type: str = "file_content"
    path: str
    content: str
    timestamp: datetime

class ConfigResponse(BaseModel):
    type: str = "config"
    config: Dict[str, Any]
    timestamp: datetime

class StatusResponse(BaseModel):
    type: str = "status"
    status: str
    uptime: float
    memory: Dict[str, float]

# Global state and WebSocket manager
class ConnectionManager:
    """Manages WebSocket connections"""
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"Client connected: {websocket.client}")

        # Send welcome message
        await self.send_personal_message(websocket, {
            "type": "system",
            "message": "Connected to Claude Code Mobile Backend",
            "timestamp": datetime.now().isoformat()
        })

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        print(f"Client disconnected: {websocket.client}")

    async def send_personal_message(self, websocket: WebSocket, message: dict):
        await websocket.send_text(json.dumps(message))

    async def broadcast(self, message: dict):
        if self.active_connections:
            dead_connections = []
            for connection in self.active_connections:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception as e:
                    print(f"Failed to send to client: {e}")
                    dead_connections.append(connection)

            # Clean up dead connections
            for dead in dead_connections:
                if dead in self.active_connections:
                    self.active_connections.remove(dead)

# Authentication
API_KEY = os.getenv("MOBILE_API_KEY", "change_this_token_in_env")

async def verify_token(authorization: str = Header(None)):
    """Verify API key from Authorization header"""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = authorization.split(" ", 1)[1]
    if token != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    return True

# Initialize FastAPI app and connection manager
manager = ConnectionManager()
app = FastAPI(
    title="Claude Code Mobile API",
    description="Backend server for controlling Claude Code from iOS",
    version="0.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global server start time for uptime tracking
START_TIME = datetime.now()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time communication"""
    token = websocket.headers.get("authorization", "Bearer ").split(" ")[1]

    # Verify token
    if token != API_KEY:
        await websocket.close(code=1008, reason="Invalid authentication")
        return

    await manager.connect(websocket)

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            message = json.loads(data)

            # Handle different message types
            await handle_websocket_message(message, websocket)

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket)

async def handle_websocket_message(message: dict, websocket: WebSocket):
    """Handle different types of WebSocket messages"""
    message_type = message.get("type")

    try:
        if message_type == "chat":
            # Forward chat message to Claude Code
            user_message = message.get("message", "")

            # Send acknowledgment
            await manager.send_personal_message(websocket, {
                "type": "ack",
                "timestamp": datetime.now().isoformat(),
                "original_id": message.get("id", "")
            })

            # TODO: Integrate with existing Claude Code logic
            # For now, echo back a response
            response = f"Echo: {user_message}"
            await manager.send_personal_message(websocket, {
                "type": "chat_response",
                "message": response,
                "timestamp": datetime.now().isoformat()
            })

        elif message_type == "command":
            # Execute command and return result
            command = message.get("command", "")
            cwd = message.get("cwd", ".")

            result = await run_command(command, cwd)
            await manager.send_personal_message(websocket, result.dict())

        elif message_type == "file_list":
            # List files in directory
            path = message.get("path", ".")
            files = await list_files(path)
            await manager.send_personal_message(websocket, {
                "type": "file_list",
                "files": files,
                "timestamp": datetime.now().isoformat()
            })

        elif message_type == "file_read":
            # Read file content
            path = message.get("path", "")
            content = await read_file(path)
            if content is not None:
                await manager.send_personal_message(websocket, {
                    "type": "file_content",
                    "path": path,
                    "content": content,
                    "timestamp": datetime.now().isoformat()
                })
            else:
                await manager.send_personal_message(websocket, {
                    "type": "error",
                    "error": "File not found or could not be read",
                    "timestamp": datetime.now().isoformat()
                })
        else:
            # Unknown message type
            await manager.send_personal_message(websocket, {
                "type": "error",
                "error": f"Unknown message type: {message_type}",
                "timestamp": datetime.now().isoformat()
            })

    except Exception as e:
        await manager.send_personal_message(websocket, {
            "type": "error",
            "error": f"Failed to handle message: {str(e)}",
            "timestamp": datetime.now().isoformat()
        })
        raise

# REST API endpoints (backup in case WebSocket fails)
@app.get("/status", response_model=StatusResponse)
async def get_status():
    """Server status endpoint"""
    process = psutil.Process()
    memory = process.memory_info()

    return StatusResponse(
        type="status",
        status="online",
        uptime=(datetime.now() - START_TIME).total_seconds(),
        memory={
            "rss_mb": memory.rss / 1024 / 1024,
            "vms_mb": memory.vms / 1024 / 1024
        }
    )

@app.get("/files/list")
async def get_file_list(path: str = ".", authenticated: bool = Depends(verify_token)):
    """REST endpoint: list files in directory"""
    try:
        files = await list_files(path)
        return {"type": "file_list", "files": files, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/files/read")
async def read_file_endpoint(request: FileReadRequest, authenticated: bool = Depends(verify_token)):
    """REST endpoint: read file content"""
    try:
        content = await read_file(request.path)
        if content is None:
            raise HTTPException(status_code=404, detail="File not found")
        return {"type": "file_content", "path": request.path, "content": content, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/files/write")
async def write_file_endpoint(request: FileWriteRequest, authenticated: bool = Depends(verify_token)):
    """REST endpoint: write file content"""
    try:
        await write_file(request.path, request.content)
        return {"type": "file_written", "path": request.path, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/command")
async def execute_command(request: CommandRequest, authenticated: bool = Depends(verify_token)):
    """REST endpoint: execute shell command"""
    try:
        result = await run_command(request.command, request.cwd)
        return result.dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/config")
async def get_config(authenticated: bool = Depends(verify_token)):
    """REST endpoint: get configuration"""
    try:
        config = {
            "api_version": "0.1.0",
            "server_time": datetime.now().isoformat(),
            "features": {
                "websocket": True,
                "rest_api": True,
                "file_operations": True,
                "command_execution": True,
                "config_management": True
            }
        }
        return ConfigResponse(type="config", config=config, timestamp=datetime.now().isoformat())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Helper functions
async def run_command(command: str, cwd: str = ".") -> CommandResponse:
    """Execute a shell command"""
    try:
        # Ensure cwd exists
        cwd_path = Path(cwd).expanduser()
        if not cwd_path.exists():
            cwd_path = Path(".")

        # Execute command
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(cwd_path)
        )

        stdout, stderr = await process.communicate()

        output = stdout.decode("utf-8", errors="ignore")
        error = stderr.decode("utf-8", errors="ignore") if stderr else None

        # Combine output and error for display
        full_output = output
        if error:
            full_output += f"\n\nSTDERR:\n{error}"

        return CommandResponse(
            type="command_result",
            output=full_output,
            exit_code=process.returncode,
            error=error if process.returncode != 0 else None,
            timestamp=datetime.now().isoformat()
        )

    except Exception as e:
        return CommandResponse(
            type="command_result",
            output="",
            exit_code=-1,
            error=f"Failed to execute command: {str(e)}",
            timestamp=datetime.now().isoformat()
        )

async def list_files(path: str = ".") -> List[Dict[str, Any]]:
    """List files in a directory"""
    try:
        target_path = Path(path).expanduser()
        if not target_path.exists():
            raise FileNotFoundError(f"Path not found: {path}")

        files = []
        for item in target_path.iterdir():
            stat = item.stat()
            files.append({
                "name": item.name,
                "type": "directory" if item.is_dir() else "file",
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
            })

        # Sort: directories first, then by name
        files.sort(key=lambda x: (x["type"] != "directory", x["name"]))

        return files
    except Exception as e:
        raise Exception(f"Failed to list files: {str(e)}")

async def read_file(path: str) -> Optional[str]:
    """Read file content"""
    try:
        file_path = Path(path).expanduser()
        if not file_path.exists() or not file_path.is_file():
            return None

        # Limit file size to prevent memory issues (max 10MB)
        if file_path.stat().st_size > 10 * 1024 * 1024:
            return "File too large (>10MB)"

        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()

    except Exception as e:
        return f"Error reading file: {str(e)}"

async def write_file(path: str, content: str):
    """Write content to file"""
    try:
        file_path = Path(path).expanduser()

        # Backup existing file
        if file_path.exists():
            backup_path = file_path.with_suffix(file_path.suffix + ".backup")
            file_path.rename(backup_path)

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

        return True
    except Exception as e:
        raise Exception(f"Failed to write file: {str(e)}")

def create_app():
    """Factory function for FastAPI app (for use in testing)"""
    return app

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8082"))
    uvicorn.run(app, host="0.0.0.0", port=port)
