import Foundation

struct LocalFile: Identifiable, Hashable {
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?

    var id: String { url.path }

    var sizeFormatted: String {
        guard !isDirectory else { return "--" }
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useKB, .useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: size)
    }

    var systemIcon: String {
        if isDirectory { return "folder.fill" }
        switch url.pathExtension.lowercased() {
        case "txt", "md", "log", "csv": return "doc.text"
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic": return "photo"
        case "mp3", "wav", "aac", "flac", "m4a": return "music.note"
        case "mp4", "mov", "avi", "mkv", "m4v": return "film"
        case "zip", "tar", "gz", "bz2", "7z", "rar": return "archivebox"
        case "swift", "py", "js", "ts", "html", "css", "cpp", "c", "h", "java", "rb", "php", "go": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }

    static func load(at url: URL) -> [LocalFile] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items.compactMap { itemURL in
            let rv = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDir = rv?.isDirectory ?? false
            let size = Int64(rv?.fileSize ?? 0)
            let date = rv?.contentModificationDate
            return LocalFile(name: itemURL.lastPathComponent, url: itemURL, isDirectory: isDir, size: size, modifiedDate: date)
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
