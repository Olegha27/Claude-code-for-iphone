# Kotlin Server

Build and run server on Kotlin. No Python needed!

## Build

```bash
cd kotlin-server
./gradlew build
```

## Run

```bash
cd kotlin-server
./gradlew run
```

Server will start at **http://localhost:8082**

## API

WebSocket: `ws://localhost:8082/ws`

HTTP:
- GET `/status` - Check server status

## Config

Set environment variables:
- `PORT` - server port (default: 8082)
- `HOST` - server host (default: 0.0.0.0)

Kotlin 1.9.25 + Ktor 2.3.7 + JDK 11+
