import SwiftUI
import AppKit

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showTransferPanel: Bool
    @State private var isDropTarget = false
    @State private var sortOrder = [KeyPathComparator(\RemoteFile.name)]

    // 現在選択中のディレクトリファイル（なければnil）
    private var selectedDirectoryFile: RemoteFile? {
        guard let id = appState.remoteSelectedFiles.first,
              let file = appState.remoteFiles.first(where: { $0.id == id }),
              file.isDirectory else { return nil }
        return file
    }

    private func openSelectedDirectory() {
        guard let file = selectedDirectoryFile else { return }
        appState.openItem(file)
    }

    private func showCreateFolderDialog() {
        let alert = NSAlert()
        alert.messageText = "新規フォルダ"
        alert.informativeText = "作成するフォルダ名を入力してください"
        alert.addButton(withTitle: "作成")
        alert.addButton(withTitle: "キャンセル")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tf.placeholderString = "フォルダ名"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task { await appState.createDirectory(name: name) }
    }

    private func showCreateFileDialog() {
        let alert = NSAlert()
        alert.messageText = "新規ファイル"
        alert.informativeText = "作成するファイル名を入力してください"
        alert.addButton(withTitle: "作成")
        alert.addButton(withTitle: "キャンセル")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tf.placeholderString = "ファイル名"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task { await appState.createRemoteFile(name: name) }
    }

    private func showDeleteConfirmDialog() {
        let count = appState.remoteSelectedFiles.count
        guard count > 0 else { return }
        let alert = NSAlert()
        alert.messageText = "\(count)個のアイテムを削除しますか？"
        alert.informativeText = "この操作は元に戻せません。"
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let toDelete = appState.remoteFiles.filter { appState.remoteSelectedFiles.contains($0.id) }
        appState.remoteSelectedFiles = []
        Task { await appState.deleteItems(toDelete) }
    }

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
                // 開く（フォルダ選択時に有効）
                Button(action: { openSelectedDirectory() }) {
                    Label("開く", systemImage: "arrow.right.circle")
                }
                .disabled(selectedDirectoryFile == nil)

                // ダウンロード（ファイル選択時に有効）
                Button(action: {
                    let files = appState.remoteFiles.filter { appState.remoteSelectedFiles.contains($0.id) }
                    Task { await appState.downloadFiles(files) }
                }) {
                    Label("ダウンロード", systemImage: "arrow.down.to.line")
                }
                .disabled(appState.remoteSelectedFiles.isEmpty)

                Button(role: .destructive, action: { showDeleteConfirmDialog() }) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .disabled(appState.remoteSelectedFiles.isEmpty)

                Divider().frame(height: 20)

                Button(action: { showCreateFolderDialog() }) {
                    Image(systemName: "folder.badge.plus")
                }

                Button(action: { Task { await appState.showUploadPanel() } }) {
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
                Table(appState.remoteFiles, selection: $appState.remoteSelectedFiles, sortOrder: $sortOrder) {
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
                .background(DoubleClickHandler(onDoubleClick: openSelectedDirectory))
                .background(RightClickHandler {
                    let menu = NSMenu()
                    menu.addItem(makeMenuItem(title: "新規フォルダ") { showCreateFolderDialog() })
                    menu.addItem(makeMenuItem(title: "新規ファイル") { showCreateFileDialog() })
                    let selected = appState.remoteSelectedFiles
                    if !selected.isEmpty {
                        let files = appState.remoteFiles.filter { selected.contains($0.id) }
                        menu.addItem(.separator())
                        if let file = files.first, file.isDirectory {
                            menu.addItem(makeMenuItem(title: "開く") { appState.openItem(file) })
                        }
                        if files.contains(where: { !$0.isDirectory }) {
                            menu.addItem(makeMenuItem(title: "ダウンロード") {
                                Task { await appState.downloadFiles(files) }
                            })
                        }
                        menu.addItem(.separator())
                        menu.addItem(makeMenuItem(title: "削除", isDestructive: true) {
                            showDeleteConfirmDialog()
                        })
                    }
                    return menu
                })
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
