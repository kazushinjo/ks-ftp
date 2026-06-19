import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(appState)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if appState.selectedProfile != nil {
                DualPaneView()
                    .environmentObject(appState)
            } else {
                WelcomeView()
                    .environmentObject(appState)
            }
        }
        .frame(minWidth: 900, minHeight: 520)
    }
}

// MARK: - Dual Pane (Local left / Remote right)

private struct DualPaneView: View {
    @EnvironmentObject var appState: AppState
    @State private var showTransferPanel = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left: Local
                    VStack(spacing: 0) {
                        paneHeader(title: "ローカル", icon: "desktopcomputer")
                        Divider()
                        LocalFileBrowserView()
                            .environmentObject(appState)
                    }
                    .frame(width: geo.size.width * 0.45)

                    Divider()

                    // Right: Remote
                    VStack(spacing: 0) {
                        paneHeader(title: "リモート: \(appState.selectedProfile?.name ?? "")", icon: "server.rack")
                        Divider()
                        FileBrowserView(showTransferPanel: $showTransferPanel)
                            .environmentObject(appState)
                    }
                    .frame(width: geo.size.width * 0.55)
                }
            }

            if showTransferPanel {
                Divider()
                TransferQueueView()
                    .environmentObject(appState)
                    .frame(height: 180)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showTransferPanel.toggle() }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                        if appState.pendingTransferCount > 0 {
                            Text("\(appState.pendingTransferCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
    }

    private func paneHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}

// MARK: - Welcome

private struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddConnection = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("KS-FTP")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("左のサイドバーから接続先を選択するか、\n新しい接続を追加してください。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("接続を追加") {
                showingAddConnection = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "globe", label: "FTP / FTPS / SFTP 対応")
                FeatureRow(icon: "arrow.left.arrow.right", label: "左ローカル・右リモートのデュアルペイン")
                FeatureRow(icon: "arrow.up.arrow.down", label: "ドラッグ&ドロップでファイル転送")
                FeatureRow(icon: "bookmark", label: "接続プロファイルの保存・管理")
            }
            .padding()
            .background(.quinary)
            .cornerRadius(10)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add)
                .environmentObject(appState)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.callout)
        }
    }
}
