import SwiftUI

@main
struct ClaudeMobileApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .environmentObject(settings)
        }
    }
}

class AppSettings: ObservableObject {
    @Published var serverURL: String
    @Published var authToken: String
    @Published var isDarkMode: Bool

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "ws://localhost:8082/ws"
        self.authToken = UserDefaults.standard.string(forKey: "authToken") ?? ""
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }

    func save() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        UserDefaults.standard.set(authToken, forKey: "authToken")
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
}
