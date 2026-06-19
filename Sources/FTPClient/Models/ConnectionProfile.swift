import Foundation

enum FTPProtocol: String, Codable, CaseIterable, Identifiable {
    case ftp = "FTP"
    case ftps = "FTPS"
    case sftp = "SFTP"

    var id: String { rawValue }

    var defaultPort: Int {
        switch self {
        case .ftp, .ftps: return 21
        case .sftp: return 22
        }
    }

    var scheme: String {
        switch self {
        case .ftp: return "ftp"
        case .ftps: return "ftps"
        case .sftp: return "sftp"
        }
    }

    var icon: String {
        switch self {
        case .ftp: return "server.rack"
        case .ftps: return "lock.shield"
        case .sftp: return "key.horizontal"
        }
    }
}

struct ConnectionProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "新しい接続"
    var host: String = ""
    var port: Int = 21
    var protocolType: FTPProtocol = .ftp
    var username: String = "anonymous"
    var password: String = ""
    var initialPath: String = "/"

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ConnectionProfile, rhs: ConnectionProfile) -> Bool {
        lhs.id == rhs.id
    }
}
