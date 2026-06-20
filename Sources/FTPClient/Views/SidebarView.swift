import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddConnection = false
    @State private var editingProfile: ConnectionProfile?

    var body: some View {
        List {
            Section {
                if appState.profiles.isEmpty {
                    VStack(spacing: 12) {
                        let iconPath = Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
                        let fallbackPath = "/Users/kazuichishinjo/アプリ開発/FTPClient/Resources/AppIcon.icns"
                        if let icon = NSImage(contentsOfFile: iconPath) ?? NSImage(contentsOfFile: fallbackPath) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .cyan.opacity(0.6), radius: 8, x: 0, y: 0)
                        }
                        Text("接続先がありません")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Button {
                            showingAddConnection = true
                        } label: {
                            Text("接続を追加")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(appState.profiles) { profile in
                        ProfileRow(profile: profile)
                            .environmentObject(appState)
                            .contextMenu {
                                Button {
                                    Task { await appState.connect(to: profile) }
                                } label: {
                                    Label("接続", systemImage: "network")
                                }
                                Button {
                                    editingProfile = profile
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    appState.deleteProfile(profile)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text("接続先")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddConnection = true
                } label: {
                    Label("接続を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddConnection) {
            ConnectionFormView(mode: .add)
                .environmentObject(appState)
        }
        .sheet(item: $editingProfile) { profile in
            ConnectionFormView(mode: .edit(profile))
                .environmentObject(appState)
        }
    }
}

private struct ProfileRow: View {
    @EnvironmentObject var appState: AppState
    let profile: ConnectionProfile

    private var isConnected: Bool {
        appState.selectedProfile?.id == profile.id
    }

    var body: some View {
        Button(action: {
            Task { await appState.connect(to: profile) }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan.opacity(0.35))
                        .frame(width: 36, height: 36)
                    Image(systemName: profile.protocolType.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name)
                        .font(.callout)
                        .fontWeight(isConnected ? .semibold : .regular)
                        .foregroundStyle(.white)
                    Text("\(profile.protocolType.rawValue)  \(profile.host)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyan.opacity(isConnected ? 0.35 : 0.15))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
