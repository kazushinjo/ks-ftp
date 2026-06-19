import SwiftUI

struct LocalFileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\LocalFile.name)]
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if appState.localFiles.isEmpty {
                emptyState
            } else {
                fileTable
            }
        }
        .alert("フォルダを作成", isPresented: $showingCreateFolder) {
            TextField("フォルダ名", text: $newFolderName)
            Button("作成") {
                let n = newFolderName; newFolderName = ""
                appState.createLocalDirectory(name: n)
            }
            Button("キャンセル", role: .cancel) { newFolderName = "" }
        }
        .confirmationDialog(
            "\(appState.localSelectedFiles.count)個のアイテムをゴミ箱に移動しますか？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("ゴミ箱に移動", role: .destructive) {
                let files = appState.localFiles.filter { appState.localSelectedFiles.contains($0.id) }
                appState.deleteLocalItems(files)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: { appState.localNavigateUp() }) {
                Image(systemName: "arrow.up")
            }
            .disabled(!appState.localCanGoUp)
            .buttonStyle(.borderless)

            Button(action: { appState.loadLocalDirectory(url: appState.localCurrentURL) }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            Button(action: {
                appState.loadLocalDirectory(url: FileManager.default.homeDirectoryForCurrentUser)
            }) {
                Image(systemName: "house")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 20)

            // Path display
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(localPathSegments, id: \.path) { seg in
                        if seg.path != "/" {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Button(seg.label) {
                            appState.localNavigateTo(url: URL(fileURLWithPath: seg.path))
                        }
                        .buttonStyle(.borderless)
                        .font(.callout)
                        .foregroundStyle(seg.path == appState.localCurrentURL.path ? .primary : .secondary)
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // 選択フォルダを開く
            if !appState.localSelectedFiles.isEmpty,
               let file = appState.localFiles.first(where: { appState.localSelectedFiles.contains($0.id) }),
               file.isDirectory {
                Button(action: { appState.openLocalItem(file) }) {
                    Label("開く", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderless)
            }

            // Upload selected local files to remote
            if !appState.localSelectedFiles.isEmpty && appState.selectedProfile != nil {
                Button(action: { Task { await appState.uploadSelectedLocalFiles() } }) {
                    Label("アップロード", systemImage: "arrow.right.to.line")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }

            Divider().frame(height: 20)

            // フォルダ作成
            Button(action: { showingCreateFolder = true }) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)

            // 削除（ゴミ箱）
            Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .foregroundColor(appState.localSelectedFiles.isEmpty ? .secondary : .red)
            }
            .buttonStyle(.borderless)
            .disabled(appState.localSelectedFiles.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
    }

    // MARK: - File Table

    private var fileTable: some View {
        Table(appState.localFiles, selection: $appState.localSelectedFiles, sortOrder: $sortOrder) {
            TableColumn("名前", value: \.name) { file in
                HStack(spacing: 6) {
                    Image(systemName: file.systemIcon)
                        .foregroundStyle(file.isDirectory ? .blue : .secondary)
                        .frame(width: 18)
                    Text(file.name)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 200)

            TableColumn("サイズ", value: \.size) { file in
                Text(file.sizeFormatted)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(70)

            TableColumn("更新日時") { file in
                if let d = file.modifiedDate {
                    Text(d, style: .date)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--").foregroundStyle(.tertiary)
                }
            }
            .width(90)
        }
        .onChange(of: sortOrder) { _, newOrder in
            appState.localFiles = appState.localFiles.sorted(using: newOrder)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            let files = appState.localFiles.filter { ids.contains($0.id) }
            if let file = files.first {
                Button("Finderで表示") { appState.revealInFinder(file) }
            }
            if appState.selectedProfile != nil && !files.filter({ !$0.isDirectory }).isEmpty {
                Button("リモートにアップロード") {
                    appState.localSelectedFiles = ids
                    Task { await appState.uploadSelectedLocalFiles() }
                }
            }
            Divider()
            Button("ゴミ箱に移動", role: .destructive) {
                appState.localSelectedFiles = ids
                showingDeleteConfirm = true
            }
        } primaryAction: { ids in
            if let id = ids.first,
               let file = appState.localFiles.first(where: { $0.id == id }) {
                appState.openLocalItem(file)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("フォルダは空です")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Path segments

    private var localPathSegments: [(label: String, path: String)] {
        var result: [(String, String)] = [("/", "/")]
        let parts = appState.localCurrentURL.path.split(separator: "/").filter { !$0.isEmpty }
        var accumulated = ""
        for part in parts {
            accumulated += "/" + part
            result.append((String(part), accumulated))
        }
        return result
    }
}
