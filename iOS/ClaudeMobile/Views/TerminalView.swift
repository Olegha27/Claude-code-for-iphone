import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settings: AppSettings

    @State private var commandText = ""
    @State private var commandHistory: [CommandOutput] = []
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Connection status
            if !connectionManager.isConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
            }

            // Command history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(commandHistory) { output in
                            CommandOutputView(output: output)
                        }
                    }
                    .padding()
                }
                .onChange(of: commandHistory.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            // Command input (at bottom)
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Current directory
                    Text("\(currentDirectory)$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)

                    // Command input
                    TextField("Enter command...", text: $commandText, axis: .vertical)
                        .focused($isFocused)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1...3)

                    // Send button
                    if !commandText.isEmpty {
                        Button(action: executeCommand) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                        .disabled(!connectionManager.isConnected)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    commandHistory.removeAll()
                }
                .disabled(commandHistory.isEmpty)
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button("Ctrl-C") {
                    // TODO: Implement signal sending
                    addCommandHistory(
                        command: "SIGINT",
                        output: "Not implemented yet",
                        exitCode: -1
                    )
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private var currentDirectory: String {
        "." // Could be tracked
    }

    private func executeCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        commandText = ""

        guard connectionManager.isConnected else {
            connectionManager.errorMessage = "Not connected"
            connectionManager.showErrorAlert = true
            return
        }

        let message = WebSocketMessage(
            type: "command",
            command: command,
            cwd: currentDirectory
        )

        // Add to command history
        let output = CommandOutput(
            command: command,
            output: "",
            exitCode: -1,
            timestamp: Date().iso8601
        )
        commandHistory.append(output)

        connectionManager.send(message: message)

        // Simulate response for now
        simulateCommandResponse(command: command)
    }

    private func simulateCommandResponse(command: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockOutput: String
            switch command {
            case "ls":
                mockOutput = "README.md\nbackend\niOS"
            case "pwd":
                mockOutput = "/Users/olegha27/Documents/GitHub/Claude-code-for-iphone"
            case "date":
                mockOutput = Date().description
            default:
                mockOutput = "Command executed: \(command)"
            }

            self.addCommandHistory(
                command: command,
                output: mockOutput,
                exitCode: 0
            )
        }
    }

    private func addCommandHistory(command: String, output: String, exitCode: Int) {
        guard let lastIndex = commandHistory.indices.last else { return }
        commandHistory[lastIndex] = CommandOutput(
            command: command,
            output: output,
            exitCode: exitCode,
            timestamp: Date().iso8601
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = commandHistory.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

struct CommandOutputView: View {
    let output: CommandOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Command prompt
            HStack(spacing: 0) {
                Text(currentDirectory)
                    .foregroundColor(.green)
                Text("$")
                    .foregroundColor(.green)
                    .padding(.leading, 4)
                Text(output.command ?? "")
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
            }
            .font(.system(.caption, design: .monospaced))

            // Output
            if !output.output.isEmpty || (output.command != nil && output.exitCode != nil) {
                HStack {
                    Text(output.output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(output.exitCode == 0 ? Color.clear : Color.red.opacity(0.1))
                .overlay {
                    if output.exitCode != 0 && output.exitCode != -1 {
                        HStack {
                            Spacer()
                            Text("✕")
                                .foregroundColor(.red)
                                .padding(.trailing, 8)
                        }
                    }
                }
            }

            // Timestamp and exit code
            if let exitCode = output.exitCode, exitCode != -1 {
                HStack {
                    Text(`Exit ( \( exitCode ) )`)
                        .font(.caption2)
                        .foregroundColor(exitCode == 0 ? .green : .red)

                    Spacer()

                    Text(formattedTime(output.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 2)
            }
        }
    }

    private var currentDirectory: String {
        "."
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

struct CommandOutput: Identifiable, Codable {
    let id = UUID()
    let command: String
    let output: String
    let exitCode: Int
    let timestamp: String

    init(command: String, output: String, exitCode: Int, timestamp: String) {
        self.command = command
        self.output = output
        self.exitCode = exitCode
        self.timestamp = timestamp
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView()
            .environmentObject(ConnectionManager())
            .environmentObject(AppSettings())
    }
}
