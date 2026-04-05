import SwiftUI
import Combine
import Network

struct ChatView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settings: AppSettings

    @State private var messageText = ""
    @State private var isTyping = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Connection status banner
            if let connectionMessage = connectionView {
                connectionMessage
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(connectionManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: connectionManager.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: connectionManager.messages.last?.timestamp) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            // Typing indicator
            if isTyping {
                HStack {
                    Text("Claude is typing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .padding(.horizontal)
            }

            // Message input
            VStack(spacing: 0) {
                Divider()

                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask Claude...", text: $messageText, axis: .vertical)
                        .focused($isFocused)
                        .lineLimit(1...5)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    if !messageText.isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    connectionManager.messages.removeAll()
                }
                .disabled(connectionManager.messages.isEmpty)
            }
        }
        .onAppear {
            connectIfNeeded()
        }
    }

    private var connectionView: some View {
        switch connectionManager.connectionStatus {
        case .connected:
            return EmptyView().eraseToAnyView()
        case .connecting:
            return AnyView(HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Connecting...")
                    .font(.caption)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1)))
        case .disconnected:
            return AnyView(HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Not connected - tap to reconnect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .onTapGesture {
                connectIfNeeded()
            })
        case .error(let message):
            return AnyView(HStack {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
                Text("Error: \(message)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1)))
        }
    }

    private func connectIfNeeded() {
        guard !connectionManager.isConnected else { return }
        connectionManager.connect(url: settings.serverURL, token: settings.authToken)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessageId = connectionManager.messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard connectionManager.isConnected else {
            connectionManager.errorMessage = "Not connected"
            connectionManager.showErrorAlert = true
            return
        }

        let message = WebSocketMessage(
            type: "chat",
            message: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        connectionManager.send(message: message)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar/icon
            if message.type == "user" {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("U")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            } else if message.type == "claude" {
                Circle()
                    .fill(Color.green)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("C")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            } else {
                Image(systemName: "info.circle")
                    .foregroundColor(.gray)
                    .font(.caption)
            }

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.type == "user" ? "You" : message.type == "claude" ? "Claude" : "System")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formattedTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(message.message)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(backgroundColor)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
        .transition(.move(edge: message.isFromUser ? .trailing : .leading).combined(with: .opacity))
    }

    private var backgroundColor: Color {
        switch message.type {
        case "user":
            return Color.blue.opacity(0.1)
        case "claude":
            return Color(.systemGray5)
        default:
            return Color.orange.opacity(0.1)
        }
    }

    private func formattedTime(_ timestamp: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: timestamp) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper for type erasure
extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ConnectionManager())
            .environmentObject(AppSettings())
    }
}
