import SwiftUI
import AppKit

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showTransferPanel: Bool
    @State private var selectedFiles = Set<String>()
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    @State private var showingDeleteConfirm = false
    @State private var isDropTarget = false
    @State private var sortOrder = [KeyPathComparator(\RemoteFile.name)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let msg = appState.errorMessage {
                errorBanner(msg)
                Divider()
            }

            if appState.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fileTable
            }

        }
        .navigationTitle(appState.selectedProfile?.name ?? "")
        .alert("フォルダを作成", isPresented: $showingCreateFolder) {
            TextField("フォルダ名", text: $newFolderName)
            Button("作成") {
                let n = newFolderName
                newFolderName = ""
                Task { await appState.createDirectory(name: n) }
            }
            Button("キャンセル", role: .cancel) { newFolderName = "" }
        }
        .confirmationDialog(
            "\(selectedFiles.count)個のアイテムを削除しますか？\nこの操作は元に戻せません。",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                let toDelete = appState.remoteFiles.filter { selectedFiles.contains($0.id) }
                selectedFiles = []
                Task { await appState.deleteItems(toDelete) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Group {
                Button(action: { Task { await appState.navigateBack() } }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!appState.canGoBack)

                Button(action: { Task { await appState.navigateForward() } }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!appState.canGoForward)

                Button(action: { Task { await appState.navigateUp() } }) {
                    Image(systemName: "arrow.up")
                }
                .disabled(!appState.canGoUp)

                Button(action: { Task { await appState.loadDirectory(path: appState.currentPath) } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 20)

            PathBar(path: appState.currentPath) { path in
                Task { await appState.navigateTo(path: path) }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 20)

            Group {
                if !selectedFiles.isEmpty {
                    // 選択アイテムを開く（フォルダ移動）
                    if let file = appState.remoteFiles.first(where: { selectedFiles.contains($0.id) }),
                       file.isDirectory {
                        Button(action: { Task { await appState.openItem(file) } }) {
                            Label("開く", systemImage: "arrow.right.circle")
                        }
                    }

                    Button(action: {
                        let files = appState.remoteFiles.filter { selectedFiles.contains($0.id) }
                        Task { await appState.downloadFiles(files) }
                    }) {
                        Label("ダウンロード", systemImage: "arrow.down.to.line")
                    }

                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }

                    Divider().frame(height: 20)
                }

                Button(action: { showingCreateFolder = true }) {
                    Image(systemName: "folder.badge.plus")
                }

                Button(action: {
                    Task { await appState.showUploadPanel() }
                }) {
                    Image(systemName: "arrow.up.to.line")
                }
            }
            .buttonStyle(.borderless)

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
    }

    // MARK: - Error Banner

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(msg)
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("閉じる") { appState.errorMessage = nil }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - File Table

    private var fileTable: some View {
        Group {
            if appState.remoteFiles.isEmpty {
                emptyState
            } else {
                Table(appState.remoteFiles, selection: $selectedFiles, sortOrder: $sortOrder) {
                    TableColumn("名前", value: \.name) { file in
                        HStack(spacing: 6) {
                            Image(systemName: file.systemIcon)
                                .foregroundStyle(file.isDirectory ? .blue : .secondary)
                                .frame(width: 18)
                            Text(file.name)
                                .lineLimit(1)
                            if file.isSymlink {
                                Text("リンク")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    .width(min: 160, ideal: 280)

                    TableColumn("サイズ", value: \.size) { file in
                        Text(file.sizeFormatted)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(80)

                    TableColumn("更新日時") { file in
                        if let d = file.modifiedDate {
                            Text(d, style: .date)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("--").foregroundStyle(.tertiary)
                        }
                    }
                    .width(100)

                    TableColumn("パーミッション") { file in
                        Text(file.permissions)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(100)
                }
                .onChange(of: sortOrder) { _, newOrder in
                    appState.remoteFiles.sort(using: newOrder)
                }
                .dropDestination(for: URL.self) { urls, _ in
                    Task { await appState.uploadFiles(urls) }
                    return true
                } isTargeted: { targeted in
                    isDropTarget = targeted
                }
                .overlay {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .background(Color.accentColor.opacity(0.08).cornerRadius(8))
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("このフォルダは空です")
                .foregroundStyle(.secondary)
            Text("ファイルをドラッグしてアップロードできます")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await appState.uploadFiles(urls) }
            return true
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08).cornerRadius(8))
            }
        }
    }
}

// MARK: - Path Bar

struct PathBar: View {
    let path: String
    let onNavigate: (String) -> Void

    private var segments: [(label: String, path: String)] {
        var result: [(String, String)] = [("/", "/")]
        let parts = path.split(separator: "/").filter { !$0.isEmpty }
        var accumulated = "/"
        for part in parts {
            accumulated += part + "/"
            result.append((String(part), accumulated))
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button(segment.label) {
                        onNavigate(segment.path)
                    }
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .foregroundStyle(idx == segments.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
