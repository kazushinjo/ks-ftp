import SwiftUI

enum ConnectionFormMode {
    case add
    case edit(ConnectionProfile)
}

struct ConnectionFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: ConnectionFormMode

    @State private var name: String = "新しい接続"
    @State private var host: String = ""
    @State private var port: String = "21"
    @State private var protocolType: FTPProtocol = .ftp
    @State private var username: String = "anonymous"
    @State private var password: String = ""
    @State private var initialPath: String = "/"

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "接続を編集" : "新しい接続")
                    .font(.headline)
                Spacer()
                Button("キャンセル") { dismiss() }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.escape)

                Button(isEditing ? "保存" : "追加") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()

            Divider()

            Form {
                Section("接続情報") {
                    TextField("接続名", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("プロトコル", selection: $protocolType) {
                        ForEach(FTPProtocol.allCases) { proto in
                            Label(proto.rawValue, systemImage: proto.icon)
                                .tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: protocolType) { _, newVal in
                        if port == "21" && newVal == .sftp {
                            port = "22"
                        } else if port == "22" && newVal != .sftp {
                            port = "21"
                        }
                    }

                    HStack {
                        TextField("ホスト名 / IPアドレス", text: $host)
                            .textFieldStyle(.roundedBorder)
                        TextField("ポート", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }

                Section("認証") {
                    TextField("ユーザー名", text: $username)
                        .textFieldStyle(.roundedBorder)
                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                Section("詳細設定") {
                    TextField("初期パス", text: $initialPath)
                        .textFieldStyle(.roundedBorder)
                }

                if protocolType == .sftp {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("SFTPは Homebrew版の curl が必要です。\nまた、初回接続時に SSH ホストキーの承認が必要な場合があります。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.bottom, 8)
        }
        .frame(width: 440)
        .onAppear(perform: loadInitialValues)
    }

    private func loadInitialValues() {
        if case .edit(let profile) = mode {
            name = profile.name
            host = profile.host
            port = String(profile.port)
            protocolType = profile.protocolType
            username = profile.username
            password = profile.password
            initialPath = profile.initialPath
        }
    }

    private func save() {
        var profile: ConnectionProfile
        if case .edit(let existing) = mode {
            profile = existing
        } else {
            profile = ConnectionProfile()
        }

        profile.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? host : name
        profile.host = host.trimmingCharacters(in: .whitespaces)
        profile.port = Int(port) ?? protocolType.defaultPort
        profile.protocolType = protocolType
        profile.username = username
        profile.password = password
        profile.initialPath = initialPath.isEmpty ? "/" : initialPath

        if isEditing {
            appState.updateProfile(profile)
        } else {
            appState.addProfile(profile)
        }

        dismiss()
    }
}
