import Foundation
import SwiftUI
import Combine
import Network

class ConnectionManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private let monitor = NWPathMonitor()
    private var serverURL: String = ""
    private var authToken: String = ""

    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private let reconnectDelay: TimeInterval = 5.0

    init() {
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self.disconnect()
                    self.errorMessage = "Network connection lost"
                    self.showErrorAlert = true
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    func connect(url: String, token: String) {
        guard !url.isEmpty else {
            errorMessage = "Server URL cannot be empty"
            showErrorAlert = true
            return
        }

        serverURL = url
        authToken = token

        disconnect()
        connectionStatus = .connecting

        guard let wsUrl = URL(string: url) else {
            connectionStatus = .error("Invalid URL format")
            errorMessage = "Invalid server URL"
            showErrorAlert = true
            return
        }

        var request = URLRequest(url: wsUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        listenForMessages()
        startPingTimer()

        isConnected = true
        connectionStatus = .connected
        reconnectAttempts = 0

        // Add system message
        let systemMessage = ChatMessage(
            type: "system",
            message: "Connected to Claude Code server",
            timestamp: Date().iso8601
        )
        messages.append(systemMessage)
    }

    func disconnect() {
        isConnected = false
        connectionStatus = .disconnected

        pingTimer?.invalidate()
        pingTimer = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        // Add system message
        let systemMessage = ChatMessage(
            type: "system",
            message: "Disconnected from server",
            timestamp: Date().iso8601
        )
        messages.append(systemMessage)
    }

    func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionStatus = .error("Max reconnection attempts reached")
            return
        }

        reconnectAttempts += 1
        connectionStatus = .connecting

        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [self] in
            self.connect(url: self.serverURL, token: self.authToken)
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { _ in
            self.reconnect()
        }
    }

    func send(message: WebSocketMessage) {
        guard isConnected, let webSocketTask = webSocketTask else {
            errorMessage = "Not connected to server"
            showErrorAlert = true
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)

            if let jsonString = String(data: data, encoding: .utf8) {
                let socketMessage = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask.send(socketMessage) { error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to send: \(error.localizedDescription)"
                            self.showErrorAlert = true
                            self.scheduleReconnect()
                        }
                    }
                }

                // Add user message to chat
                if message.type == "chat" {
                    let userMessage = ChatMessage(
                        type: "user",
                        message: message.message ?? "",
                        timestamp: Date().iso8601
                    )
                    messages.append(userMessage)
                }
            }
        } catch {
            errorMessage = "Failed to encode message: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()

            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Connection error: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleIncomingMessage(_ text: String) {
        do {
            guard let data = text.data(using: .utf8) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try to parse as a response message
            if let response = try? decoder.decode(ResponseMessage.self, from: data) {
                DispatchQueue.main.async {
                    self.processResponse(response)
                }
            }
        } catch {
            print("Failed to parse message: \(text)")
        }
    }

    private func processResponse(_ response: ResponseMessage) {
        if response.type == "chat_response" {
            let message = ChatMessage(
                type: "claude",
                message: response.message ?? "",
                timestamp: response.timestamp ?? Date().iso8601
            )
            messages.append(message)
        } else if response.type == "command_result" {
            let commandMessage = ChatMessage(
                type: "system",
                message: "Command executed (exit code: \(response.exit_code ?? -1))\n\(response.output ?? "")",
                timestamp: response.timestamp ?? Date().iso8601
            )
            messages.append(commandMessage)
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard isConnected else { return }
        let pingMessage = WebSocketMessage(type: "ping")
        send(message: pingMessage)
    }

    deinit {
        monitor.cancel()
        disconnect()
    }
}

// Helper structures
struct ResponseMessage: Codable {
    let type: String
    var message: String?
    let timestamp: String?
    var output: String?
    let exit_code: Int?
}

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}

class HTTPService {
    static let shared = HTTPService()
    private let session = URLSession.shared

    func listFiles(path: String, authToken: String = "") async throws -> [FileItem] {
        guard let url = URL(string: "http://localhost:8082/files/list") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let filesData = json?["files"] as? [[String: Any]] else {
            return []
        }

        var files: [FileItem] = []
        for fileData in filesData {
            if let name = fileData["name"] as? String, let type = fileData["type"] as? String {
                files.append(FileItem(
                    name: name,
                    type: type,
                    size: fileData["size"] as? Int,
                    modified: fileData["modified"] as? String
                ))
            }
        }
        return files
    }

    func readFile(path: String, authToken: String = "") async throws -> String {
        guard let url = URL(string: "http://localhost:8082/files/read") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["type": "file_read" as CFString, "path": path as CFString] as NSDictionary
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload as Any)

        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? String else {
            throw URLError(.unknown)
        }
        return content
    }

    func executeCommand(command: String, cwd: String, authToken: String = "") async throws -> CommandResponse {
        guard let url = URL(string: "http://localhost:8082/command") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "type": "command",
            "command": command,
            "cwd": cwd
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(CommandResponse.self, from: data)
    }
}
