import Foundation
import SwiftUI

struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    let type: String
    let message: String
    let timestamp: String
    var isFromUser: Bool {
        return type == "user"
    }
    var isFromClaude: Bool {
        return type == "claude"
    }
    var datetime: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }
}

struct FileItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: String
    let size: Int?
    let modified: String?

    var isDirectory: Bool {
        return type == "directory"
    }
    var icon: String {
        return isDirectory ? "folder" : "doc"
    }
    var formattedSize: String {
        guard let size = size else { return "" }
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        }
    }
}

struct CommandResponse: Codable {
    let type: String
    let output: String
    let exit_code: Int
    let timestamp: String
    let error: String?
}

struct WebSocketMessage: Codable {
    let type: String
    let message: String?
    let command: String?
    let cwd: String?
    let path: String?
    let content: String?
    let id: String?

    init(type: String, message: String? = nil, command: String? = nil, cwd: String? = nil, path: String? = nil, content: String? = nil) {
        self.type = type
        self.message = message
        self.command = command
        self.cwd = cwd
        self.path = path
        self.content = content
        self.id = UUID().uuidString
    }
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)

    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
