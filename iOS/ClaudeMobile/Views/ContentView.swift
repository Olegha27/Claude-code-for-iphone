import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settings: AppSettings
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var selectedTab: Tab = .chat

    enum Tab {
        case chat, files, terminal, settings
    }

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
        } else {
            NavigationView {
                TabView(selection: $selectedTab) {
                    ChatView()
                        .tabItem {
                            Label("Chat", systemImage: "message")
                        }
                        .tag(Tab.chat)

                    FileBrowserView()
                        .tabItem {
                            Label("Files", systemImage: "folder")
                        }
                        .tag(Tab.files)

                    TerminalView()
                        .tabItem {
                            Label("Terminal", systemImage: "terminal")
                        }
                        .tag(Tab.terminal)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(Tab.settings)
                }
                .navigationTitle("Claude Mobile")
                .accentColor(.blue)
                .onAppear {
                    if !connectionManager.isConnected {
                        connectionManager.connect(url: settings.serverURL, token: settings.authToken)
                    }
                }
            }
            .alert("Connection Error", isPresented: $connectionManager.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(connectionManager.errorMessage ?? "Unknown error")
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var pageIndex = 0

    private let pages = [
        ("Welcome to Claude Mobile", "Control Claude Code from your iPhone", "folder.badge.plus"),
        ("Real-time Chat", "Send messages to Claude and get responses", "message"),
        ("File Browser", "View and edit your project files", "doc.text"),
        ("Terminal Access", "Run commands directly from your phone", "terminal"),
        ("Get Started", "Configure your server settings to begin", "gear")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if pageIndex == 4 {
                Image(systemName: pages[pageIndex].2)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text(pages[pageIndex].0)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(pages[pageIndex].1)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Button("Configure Settings") {
                    hasSeenOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                TabView(selection: $pageIndex) {
                    ForEach(0..<4, id: \.self) { index in
                        VStack(spacing: 20) {
                            Spacer()

                            Image(systemName: pages[index].2)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)

                            Text(pages[index].0)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text(pages[index].1)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ConnectionManager())
            .environmentObject(AppSettings())
    }
}
