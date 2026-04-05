# Claude Code Mobile Server

Backend server for controlling Claude Code from iOS.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your API keys and secure token
```

3. Run server:
```bash
python main.py
```

## API

### WebSocket (ws://localhost:8082/ws)

Authenticate with:
```
Authorization: Bearer YOUR_TOKEN
```

Message types:
- `chat` - Send message to Claude
- `command` - Execute shell command
- `file_list` - List directory contents
- `file_read` - Read file content
- `config` - Get/set configuration

### REST Endpoints

```
/status           GET - Server status
/files/list       GET - List files
/files/read       POST - Read file
/files/write      POST - Write file
/command          POST - Execute command
/config           GET - Get configuration
```

## Development

Test with websocat:
```bash
websocat ws://localhost:8082/ws -H "Authorization: Bearer TOKEN"
```

## Security

- Uses Bearer token authentication
- Configure firewall for internet access
- Consider Cloudflare Tunnel for remote connection
- Set secure MOBILE_API_KEY in .env
