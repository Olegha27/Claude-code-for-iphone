# Claude Mobile

iOS app (SwiftUI) with FastAPI backend server for controlling Claude Code from your iPhone.

## Project Structure

```
Claude-code-for-iphone/
├── backend/              # Python FastAPI server
│   ├── main.py          # Server entry point
│   ├── mobile_api.py    # WebSocket + REST API
│   ├── requirements.txt # Python dependencies
│   ├── .env.example     # Configuration template
│   └── README.md        # Backend setup instructions
│
└── iOS/                 # SwiftUI iPhone app
    ├── ClaudeMobile.xcodeproj/
    └── ClaudeMobile/
        ├── App.swift
        ├── ContentView.swift
        ├── Views/
        │   ├── ChatView.swift
        │   ├── FileBrowserView.swift
        │   ├── TerminalView.swift
        │   └── SettingsView.swift
        ├── Models/
        │   └── Message.swift
        └── Services/
            └── ConnectionManager.swift

```

## Quick Start

### Backend Setup (Mac)

1. Install dependencies:
```bash
cd backend
pip install -r requirements.txt
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your NVIDIA API keys and generate a secure token
generate_secure_token() { openssl rand -base64 32; }
export MOBILE_API_KEY=$(generate_secure_token)
```

3. Run server:
```bash
python main.py
# Server runs at http://localhost:8082
```

### iOS App Setup

1. Open `iOS/ClaudeMobile.xcodeproj` in Xcode
2. Configure signing (Team + Bundle ID)
3. Build and run on device or simulator
4. In Settings:
   - **Server URL**: `ws://your-mac-ip:8082/ws` (or `ws://localhost:8082/ws` for simulator)
   - **Auth Token**: Use same token from `.env`
5. Test connection

### Network Access

For local network access:
```bash
# Find Mac IP
ipconfig getifaddr en0
```

For internet access:
- Option 1: Cloudflare Tunnel (recommended)
  ```bash
  cloudflared tunnel --url http://localhost:8082
  ```
- Option 2: ngrok
  ```bash
  ngrok http 8082
  ```
- Option 3: SSH tunnel
  ```bash
  ssh -R 8082:localhost:8082 user@server
  ```

## API Documentation

### WebSocket (`/ws`)

Authenticate via `Authorization: Bearer TOKEN` header.

**Messages**:
- `chat` - Chat with Claude
- `command` - Execute shell command
- `file_list` - List files
- `file_read` - Read file
- `file_write` - Write file
- `config` - Get/set config

### REST Endpoints

```
/status           GET    - Server status
/files/list       GET    - List files in directory
/files/read       POST   - Read file content
/files/write      POST   - Write file
/command          POST   - Execute command
/config           GET    - Get configuration
```

## Testing

Test WebSocket with `websocat`:
```bash
websocat ws://localhost:8082/ws -H "Authorization: Bearer TOKEN"
```

Then send:
```json
{"type": "chat", "message": "Hello Claude"}
```

## Features

- ✅ Real-time chat with Claude
- ✅ File browsing and editing
- ✅ Terminal command execution
- ✅ Configuration management
- ✅ Connection status monitoring
- ✅ Auto reconnection
- ⚠️ Claude Code integration (needs integration with existing logic)

## Security

- Bearer token authentication
- HTTPS via Cloudflare Tunnel
- Input validation
- Path restrictions (configurable)
- File size limits (10MB default)

## TODOs

- Integrate with existing Claude Code / free-claude-code
- Implement actual file operations (currently simulated)
- Add command history
- Syntax highlighting for files
- Add search across files
- Support multiple projects
- Real-time typing indicator
- Command suggestions
- Dark mode improvements
- Better error handling
- Unit tests

## Troubleshooting

**Connection failed**:
- Check Mac and iPhone are on same WiFi
- Verify server is running: `curl http://localhost:8082/status`
- Check Firewall: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`
- Try IP instead of hostname

**Authentication failed**:
- Ensure token matches between .env and app
- Check token doesn't contain whitespace
- Try regenerating token

**File operations not working**:
- Verify ALLOWED_PATHS in .env
- Check file permissions
- Ensure path exists

## License

Same as free-claude-code

## Contributing

1. Fork repository
2. Create feature branch
3. Add tests
4. Submit pull request
