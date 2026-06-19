import Foundation
import SwiftUI
import AppKit

@MainActor
class AppState: ObservableObject {
    // Remote
    @Published var profiles: [ConnectionProfile] = []
    @Published var selectedProfile: ConnectionProfile?
    @Published var remoteFiles: [RemoteFile] = []
    @Published var currentPath: String = "/"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var transfers: [TransferItem] = []

    // Local
    @Published var localFiles: [LocalFile] = []
    @Published var localCurrentURL: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var localSelectedFiles = Set<String>()

    private var pathHistory: [String] = ["/"]
    private var historyIndex: Int = 0
    private let profilesKey = "ftp_client_profiles_v1"

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < pathHistory.count - 1 }
    var canGoUp: Bool {
        let p = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return !p.isEmpty
    }
    var localCanGoUp: Bool { localCurrentURL.path != "/" }
    var pendingTransferCount: Int {
        transfers.filter { !$0.isFinished }.count
    }

    init() {
        loadProfiles()
        loadLocalDirectory(url: localCurrentURL)
    }

    // MARK: - Profile Management

    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            profiles = decoded
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    func addProfile(_ profile: ConnectionProfile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: ConnectionProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            saveProfiles()
        }
    }

    func deleteProfile(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfile?.id == profile.id {
            disconnect()
        }
        saveProfiles()
    }

    // MARK: - Connection

    func connect(to profile: ConnectionProfile) async {
        selectedProfile = profile
        let startPath = profile.initialPath.isEmpty ? "/" : profile.initialPath
        pathHistory = [startPath]
        historyIndex = 0
        await loadDirectory(path: startPath)
    }

    func disconnect() {
        selectedProfile = nil
        remoteFiles = []
        currentPath = "/"
        pathHistory = ["/"]
        historyIndex = 0
        errorMessage = nil
    }

    // MARK: - Navigation

    func loadDirectory(path: String) async {
        guard let profile = selectedProfile else { return }
        isLoading = true
        errorMessage = nil

        do {
            let files = try await FTPService.listDirectory(profile: profile, path: path)
            remoteFiles = files
            currentPath = path.hasSuffix("/") ? path : path + "/"
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func navigateTo(path: String) async {
        if historyIndex < pathHistory.count - 1 {
            pathHistory = Array(pathHistory[0...historyIndex])
        }
        pathHistory.append(path)
        historyIndex = pathHistory.count - 1
        await loadDirectory(path: path)
    }

    func navigateBack() async {
        guard canGoBack else { return }
        historyIndex -= 1
        await loadDirectory(path: pathHistory[historyIndex])
    }

    func navigateForward() async {
        guard canGoForward else { return }
        historyIndex += 1
        await loadDirectory(path: pathHistory[historyIndex])
    }

    func navigateUp() async {
        let trimmed = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = trimmed.split(separator: "/")
        guard !parts.isEmpty else { return }
        let parent = parts.dropLast().joined(separator: "/")
        await navigateTo(path: parent.isEmpty ? "/" : "/" + parent + "/")
    }

    func openItem(_ file: RemoteFile) {
        guard file.isDirectory else { return }
        debugLog("openItem: \(file.path)")
        Task { await navigateTo(path: file.path) }
    }

    private func debugLog(_ msg: String) {
        let line = "[AppState] \(msg)\n"
        let url = URL(fileURLWithPath: "/tmp/ks-ftp-debug.log")
        if let data = line.data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            } else {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Local Navigation

    func loadLocalDirectory(url: URL) {
        localCurrentURL = url
        localFiles = LocalFile.load(at: url)
    }

    func localNavigateTo(url: URL) {
        loadLocalDirectory(url: url)
    }

    func localNavigateUp() {
        guard localCanGoUp else { return }
        loadLocalDirectory(url: localCurrentURL.deletingLastPathComponent())
    }

    func openLocalItem(_ file: LocalFile) {
        if file.isDirectory {
            loadLocalDirectory(url: file.url)
        } else {
            NSWorkspace.shared.open(file.url)
        }
    }

    func revealInFinder(_ file: LocalFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    // MARK: - Transfers

    // Download remote files to the current local folder
    func downloadFiles(_ files: [RemoteFile]) async {
        guard let profile = selectedProfile else { return }
        let destURL = localCurrentURL

        for file in files where !file.isDirectory {
            let idx = transfers.count
            transfers.append(TransferItem(name: file.name, isUpload: false, status: .inProgress))

            let localURL = destURL.appendingPathComponent(file.name)
            do {
                try await FTPService.download(profile: profile, remotePath: file.path, localURL: localURL)
                transfers[idx].status = .completed
                transfers[idx].progress = 1.0
            } catch {
                transfers[idx].status = .failed(error)
            }
        }
        loadLocalDirectory(url: localCurrentURL)
    }

    func uploadFiles(_ localURLs: [URL]) async {
        guard let profile = selectedProfile else { return }

        for localURL in localURLs {
            let remotePath = currentPath + localURL.lastPathComponent
            let idx = transfers.count
            transfers.append(TransferItem(name: localURL.lastPathComponent, isUpload: true, status: .inProgress))

            do {
                try await FTPService.upload(profile: profile, localURL: localURL, remotePath: remotePath)
                transfers[idx].status = .completed
                transfers[idx].progress = 1.0
            } catch {
                transfers[idx].status = .failed(error)
            }
        }

        await loadDirectory(path: currentPath)
    }

    // Upload currently selected local files to remote
    func uploadSelectedLocalFiles() async {
        guard selectedProfile != nil else { return }
        let urls = localFiles
            .filter { localSelectedFiles.contains($0.id) && !$0.isDirectory }
            .map { $0.url }
        guard !urls.isEmpty else { return }
        await uploadFiles(urls)
    }

    func showUploadPanel() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "アップロードするファイルを選択してください"
        panel.prompt = "アップロード"
        guard panel.runModal() == .OK else { return }
        await uploadFiles(panel.urls)
    }

    // MARK: - File Operations

    func createDirectory(name: String) async {
        guard let profile = selectedProfile else { return }
        let newPath = currentPath + name
        do {
            try await FTPService.createDirectory(profile: profile, path: newPath)
            await loadDirectory(path: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItems(_ files: [RemoteFile]) async {
        guard let profile = selectedProfile else { return }
        var hasError = false

        for file in files {
            do {
                if file.isDirectory {
                    try await FTPService.deleteDirectory(profile: profile, path: file.path)
                } else {
                    try await FTPService.deleteFile(profile: profile, path: file.path)
                }
            } catch {
                errorMessage = error.localizedDescription
                hasError = true
            }
        }

        if !hasError { errorMessage = nil }
        await loadDirectory(path: currentPath)
    }

    func clearFinishedTransfers() {
        transfers.removeAll { $0.isFinished }
    }
}
