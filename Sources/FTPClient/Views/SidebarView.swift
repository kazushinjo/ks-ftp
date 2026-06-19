import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddConnection = false
    @State private var editingProfile: ConnectionProfile?

    var body: some View {
        List {
            Section {
                if appState.profiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "network.slash")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("接続先がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("接続を追加") {
                            showingAddConnection = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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
            }
        }
        .listStyle(.sidebar)
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
                        .fill(isConnected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: profile.protocolType.icon)
                        .foregroundStyle(isConnected ? .white : .secondary)
                        .font(.system(size: 14))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name)
                        .font(.callout)
                        .fontWeight(isConnected ? .semibold : .regular)
                        .foregroundStyle(.primary)
                    Text("\(profile.protocolType.rawValue)  \(profile.host)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
