import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settings: AppSettings

    @State private var files: [FileItem] = []
    @State private var currentPath: String = "."
    @State private var loading = false
    @State private var selectedFile: FileItem?
    @State private var showingFileContent = false
    @State private var fileContent: String = ""

    var body: some View {
        NavigationView {
            List {
                // Current path header
                Section {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        Text(currentPath == "." ? "Root Directory" : currentPath)
                            .font(.headline)
                    }
                }

                // Parent directory (if not at root)
                if currentPath != "." {
                    Section {
                        Button(action: goToParent) {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .foregroundColor(.blue)
                                Text("Parent Directory")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Files and directories
                Section {
                    ForEach(files) { file in
                        FileRow(file: file) {
                            if file.isDirectory {
                                navigateToDirectory(file.name)
                            } else {
                                selectedFile = file
                                loadFileContent()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadFiles()
                    }
                    .disabled(loading)
                }
            }
            .refreshable {
                loadFiles()
            }
            .onAppear {
                loadFiles()
            }
            .overlay {
                if loading {
                    ProgressView("Loading files...")
                }
            }
        }
        .sheet(item: $selectedFile) { file in
            FileContentView(file: file, content: $fileContent)
        }
    }

    private func loadFiles() {
        guard connectionManager.isConnected else {
            connectionManager.errorMessage = "Not connected"
            connectionManager.showErrorAlert = true
            return
        }

        loading = true

        let message = WebSocketMessage(type: "file_list", path: currentPath)
        connectionManager.send(message: message)

        // TODO: Receive file list via response
        // For now, simulate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            files = [
                FileItem(name: "README.md", type: "file", size: 1024, modified: Date().iso8601),
                FileItem(name: "backend", type: "directory", size: nil, modified: Date().iso8601),
                FileItem(name: "iOS", type: "directory", size: nil, modified: Date().iso8601)
            ]
            loading = false
        }
    }

    private func navigateToDirectory(_ directory: String) {
        currentPath = currentPath == "." ? directory : "\(currentPath)/\(directory)"
        loadFiles()
    }

    private func goToParent() {
        let components = currentPath.split(separator: "/")
        if components.count <= 1 {
            currentPath = "."
        } else {
            currentPath = components.dropLast().joined(separator: "/")
        }
        loadFiles()
    }

    private func loadFileContent() {
        guard let file = selectedFile else { return }

        let message = WebSocketMessage(type: "file_read", path: "\(currentPath)/\(file.name)")
        connectionManager.send(message: message)

        // TODO: Receive file content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            fileContent = "// File content for \(file.name)\n\n// Implementation would load the actual file content here."
        }
    }
}

struct FileRow: View {
    let file: FileItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: file.icon)
                    .foregroundColor(file.isDirectory ? .yellow : .gray)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)

                    HStack {
                        if file.isDirectory {
                            Text("Folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(file.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if !file.isDirectory {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FileContentView: View {
    let file: FileItem
    @Binding var content: String
    @State private var editedContent: String = ""
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            if isEditing {
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(.systemBackground))
                    .onAppear {
                        editedContent = content
                    }
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveContent()
                    }
                    isEditing.toggle()
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Hide") {
                    hideKeyboard()
                }
            }
        }
    }

    private func saveContent() {
        content = editedContent
        // TODO: Send to server
        print("File saved (not implemented)")
    }
}

struct FileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowserView()
            .environmentObject(ConnectionManager())
            .environmentObject(AppSettings())
    }
}

extension Date {
    static var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
