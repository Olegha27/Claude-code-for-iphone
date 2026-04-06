package com.olegha.claudemobile

import io.ktor.server.application.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import java.time.Duration

@Serializable
data class Message(
    val type: String,
    val message: String? = null,
    val command: String? = null,
    val cwd: String? = null,
    val path: String? = null,
    val content: String? = null,
    val timestamp: String? = null
)

fun main(args: Array<String>) {
    val port = System.getenv("PORT")?.toInt() ?: 8082
    val host = System.getenv("HOST") ?: "0.0.0.0"

    val server = io.ktor.server.netty.NettyApplicationEngine
        .embeddedServer(io.ktor.server.netty.Netty, port = port, host = host) {
            install(io.ktor.server.plugins.contentnegotiation.ContentNegotiation) {
                json(Json { prettyPrint = true; isLenient = true })
            }
            install(io.ktor.server.plugins.cors.routing.CORS) {
                anyHost()
                allowHeader("Authorization")
                allowHeader("Content-Type")
                allowMethod(io.ktor.http.HttpMethod.Get)
                allowMethod(io.ktor.http.HttpMethod.Post)
            }
            install(io.ktor.server.websocket.WebSockets) {
                pingPeriod = Duration.ofSeconds(15)
                timeout = Duration.ofSeconds(15)
                maxFrameSize = Long.MAX_VALUE
                masking = false
            }
            install(io.ktor.server.plugins.calllogging.CallLogging)

            routing {
                webSocket("/ws") {
                    ConnectionManager.handleConnection(this)
                }
                get("/status") {
                    call.respondText("Server is running")
                }
            }
        }

    server.start(wait = true)
}

object ConnectionManager {
    private val connections = mutableListOf<WebSocketSession>()

    suspend fun handleConnection(session: DefaultWebSocketServerSession) {
        connections.add(session)

        try {
            session.send("Connected to Claude Code Mobile Backend")

            for (frame in session.incoming) {
                when (frame) {
                    is Frame.Text -> {
                        val message = Json.decodeFromString<Message>(frame.readText())
                        handleMessage(message, session)
                    }
                    is Frame.Close -> break
                    else -> {}
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            connections.remove(session)
        }
    }

    private suspend fun handleMessage(message: Message, session: WebSocketSession) {
        when (message.type) {
            "chat" -> handleChat(message, session)
            "command" -> handleCommand(message, session)
            "file_list" -> handleFileList(message, session)
            "file_read" -> handleFileRead(message, session)
            "ping" -> session.send("pong")
            else -> session.send("Unknown type: ${message.type}")
        }
    }

    private suspend fun handleChat(message: Message, session: WebSocketSession) {
        val response = Message(
            type = "chat_response",
            message = "Echo: ${message.message}",
            timestamp = java.time.Instant.now().toString()
        )
        session.send(Json.encodeToString(response))
    }

    private suspend fun handleCommand(message: Message, session: WebSocketSession) {
        try {
            val process = ProcessBuilder()
                .command("/bin/bash", "-c", message.command ?: "")
                .directory(java.io.File(message.cwd ?: "."))
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .redirectError(ProcessBuilder.Redirect.PIPE)
                .start()

            val output = process.inputStream.bufferedReader().readText()
            val error = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()

            val response = Message(
                type = "command_result",
                output = if (error.isNotEmpty()) output + "

STDERR:\n" + error else output,
                timestamp = java.time.Instant.now().toString()
            )
            session.send(Json.encodeToString(response))
        } catch (e: Exception) {
            session.send("Error: ${e.message}")
        }
    }

    private suspend fun handleFileList(message: Message, session: WebSocketSession) {
        val path = java.io.File(message.path ?: ".")
        if (path.exists() && path.isDirectory) {
            val files = path.listFiles()?.map { file ->
                mapOf(
                    "name" to file.name,
                    "type" to if (file.isDirectory) "directory" else "file",
                    "size" to file.length(),
                    "modified" to java.time.Instant.ofEpochMilli(file.lastModified()).toString()
                )
            } ?: emptyList()

            session.send(Json.encodeToString(files))
        }
    }

    private suspend fun handleFileRead(message: Message, session: WebSocketSession) {
        val file = java.io.File(message.path ?: "")
        if (file.exists() && file.isFile) {
            val content = file.readText()
            val response = Message(
                type = "file_content",
                content = content,
                timestamp = java.time.Instant.now().toString()
            )
            session.send(Json.encodeToString(response))
        }
    }
}
