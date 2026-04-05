import SwiftUI
import Network

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var connectionManager: ConnectionManager

    @State private var showTestConnection = false
    @State private var testMessage: String = ""
    @State private var testSuccess: Bool = false

    var body: some View {
        Form {
            // Connection Settings
            Section(header: Text("Server Configuration")) {
                TextField("Server URL", text: $settings.serverURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)

                SecureField("Auth Token", text: $settings.authToken)
                    .autocapitalization(.none)

                Button("Save Configuration") {
                    settings.save()
                    testMessage = "Settings saved"
                    showTestConnection = true
                    testSuccess = true
                }
            }

            // Connection Status
            Section(header: Text("Connection Status")) {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(connectionManager.connectionStatus.description)
                        .foregroundColor(connectionStatusColor)
                }

                Button(action: testConnection) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Test Connection")
                    }
                }
                .disabled(settings.serverURL.isEmpty || settings.authToken.isEmpty)
            }

            // Server Management
            Section(header: Text("Connection")) {
                if connectionManager.isConnected {
                    Button("Disconnect") {
                        connectionManager.disconnect()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Connect") {
                        connectionManager.connect(url: settings.serverURL, token: settings.authToken)
                    }
                    .disabled(settings.serverURL.isEmpty || settings.authToken.isEmpty)
                }
            }

            // Help
            Section(header: Text("Help")) {
                NavigationLink(destination: HelpView()) {
                    Label("How to Setup", systemImage: "questionmark.circle")
                }

                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }

            // Debug
            if showTestConnection {
                Section(header: Text("Connection Test")) {
                    if testSuccess {
                        Label(testMessage, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label(testMessage, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Load current values
            settings.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
            settings.authToken = UserDefaults.standard.string(forKey: "authToken") ?? ""
        }
    }

    private var connectionStatusColor: Color {
        switch connectionManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }

    private func testConnection() {
        guard !settings.serverURL.isEmpty else {
            testMessage = "Server URL cannot be empty"
            testSuccess = false
            showTestConnection = true
            return
        }

        guard !settings.authToken.isEmpty else {
            testMessage = "Auth token cannot be empty"
            testSuccess = false
            showTestConnection = true
            return
        }

        testMessage = "Connecting to \(settings.serverURL)..."
        testSuccess = true
        showTestConnection = true

        connectionManager.connect(url: settings.serverURL, token: settings.authToken)
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Setup Instructions")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 10)

                Text("1. Run the backend server on your Mac:")
                    .font(.headline)

                CodeBlock(text: "cd backend\npython main.py")

                Text("2. Find your Mac's IP address:")
                    .font(.headline)

                Text("Settings → Network → Wi-Fi → IP Address")
                    .padding(.leading)

                Text("3. Configure the iOS app:")
                    .font(.headline)

                Text("Replace localhost with your Mac IP in Settings")
                    .padding(.leading)

                Text("4. Generate a secure token:")
                    .font(.headline)

                CodeBlock(text: "openssl rand -base64 32")

                Text("5. Copy this token to both .env and iOS Settings")
                    .padding(.leading)

                Text("6. Test the connection!")
                    .font(.headline)

                Divider()

                Text("Remote Access")
                    .font(.title2)
                    .bold()

                Text("For access outside your local network, you have options:")

                Group {
                    Text("• Cloudflare Tunnel (recommended)")
                        .font(.headline)
                    Text("  Easy to setup, secure, free")
                        .padding(.leading)

                    Text("• ngrok")
                        .font(.headline)
                        .padding(.top)
                    Text("  Simple tunneling, free tier available")
                        .padding(.leading)

                    Text("• SSH port forwarding")
                        .font(.headline)
                        .padding(.top)
                    Text("  Requires server with SSH access")
                        .padding(.leading)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Help")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Claude Mobile")
                .font(.title)
                .bold()

            Text("Version 0.1.0")
                .foregroundColor(.secondary)

            Text("Control Claude Code from your iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()

            List {
                Link("GitHub Repository", destination: URL(string: "https://github.com/Olegha27/Claude-code-for-iphone")!)
                Link("Claude Code", destination: URL(string: "https://github.com/Olegha27/free-claude-code")!)
            }
            .frame(height: 100)
        }
        .padding()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ConnectionManager())
            .environmentObject(AppSettings())
    }
}

// Helper views
struct CodeBlock: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}
