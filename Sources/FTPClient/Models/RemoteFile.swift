import Foundation

struct RemoteFile: Identifiable, Hashable {
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let isSymlink: Bool
    let modifiedDate: Date?
    let permissions: String

    var id: String { path }

    var sizeFormatted: String {
        guard !isDirectory else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var systemIcon: String {
        if isDirectory { return "folder.fill" }
        if isSymlink { return "arrow.right.square" }
        switch (name as NSString).pathExtension.lowercased() {
        case "txt", "md", "log", "csv": return "doc.text"
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic": return "photo"
        case "mp3", "wav", "aac", "flac", "m4a": return "music.note"
        case "mp4", "mov", "avi", "mkv", "m4v": return "film"
        case "zip", "tar", "gz", "bz2", "7z", "rar": return "archivebox"
        case "swift", "py", "js", "ts", "html", "css", "cpp", "c", "h", "java", "rb", "php", "go", "rs": return "chevron.left.forwardslash.chevron.right"
        case "dmg", "pkg", "app": return "app.badge"
        default: return "doc"
        }
    }

    var iconColor: String {
        if isDirectory { return "blue" }
        return "secondary"
    }
}
