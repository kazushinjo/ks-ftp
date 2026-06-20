import Foundation

private extension String {
    func appendTo(url: URL) throws {
        if let data = self.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: url)
            }
        }
    }
}

enum FTPError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case permissionDenied
    case fileNotFound
    case transferFailed(String)
    case curlNotFound

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "接続に失敗しました: \(msg)"
        case .authenticationFailed: return "認証に失敗しました。ユーザー名とパスワードを確認してください。"
        case .permissionDenied: return "アクセス権限がありません"
        case .fileNotFound: return "ファイルまたはディレクトリが見つかりません"
        case .transferFailed(let msg): return "転送に失敗しました: \(msg)"
        case .curlNotFound: return "curl コマンドが見つかりません"
        }
    }
}

struct FTPService {

    // MARK: - curl Path Detection

    static var curlPath: String {
        let candidates = [
            "/opt/homebrew/bin/curl",
            "/usr/local/bin/curl",
            "/usr/bin/curl"
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/curl"
    }

    // MARK: - URL Building

    static func buildURL(profile: ConnectionProfile, path: String) -> String {
        let user = profile.username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? profile.username
        let pass = profile.password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? profile.password
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        let normalizedPath = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        let encodedPath = normalizedPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalizedPath
        return "\(profile.protocolType.scheme)://\(user):\(pass)@\(profile.host):\(profile.port)\(encodedPath)"
    }

    // MARK: - Directory Listing

    static func listDirectory(profile: ConnectionProfile, path: String) async throws -> [RemoteFile] {
        let dirPath = path.hasSuffix("/") ? path : path + "/"
        let url = buildURL(profile: profile, path: dirPath)

        var args = ["-s", "--connect-timeout", "10", url]
        if profile.protocolType == .ftps {
            args += ["--ftp-ssl", "--insecure"]
        } else if profile.protocolType == .sftp {
            args += ["--insecure"]
        }

        let (output, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }

        return parseDirectoryListing(output: output, basePath: dirPath)
    }

    // MARK: - Download

    static func download(
        profile: ConnectionProfile,
        remotePath: String,
        localURL: URL
    ) async throws {
        let url = buildURL(profile: profile, path: remotePath)

        var args = ["-s", "--connect-timeout", "10", "-o", localURL.path, url]
        if profile.protocolType == .ftps {
            args += ["--ftp-ssl", "--insecure"]
        } else if profile.protocolType == .sftp {
            args += ["--insecure"]
        }

        let (_, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }
    }

    // MARK: - Upload

    static func upload(
        profile: ConnectionProfile,
        localURL: URL,
        remotePath: String
    ) async throws {
        let url = buildURL(profile: profile, path: remotePath)

        var args = ["-s", "--connect-timeout", "10", "-T", localURL.path]
        if profile.protocolType == .ftp || profile.protocolType == .ftps {
            args += ["--ftp-create-dirs"]
        }
        if profile.protocolType == .ftps {
            args += ["--ftp-ssl", "--insecure"]
        } else if profile.protocolType == .sftp {
            args += ["--insecure"]
        }
        args.append(url)

        let (_, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }
    }

    // MARK: - Create Directory

    static func createDirectory(profile: ConnectionProfile, path: String) async throws {
        let baseURL = buildURL(profile: profile, path: "/")
        var args: [String]

        if profile.protocolType == .sftp {
            args = ["-s", "--connect-timeout", "10", "--insecure", "-Q", "mkdir \(path)", baseURL]
        } else {
            args = ["-s", "--connect-timeout", "10", "-Q", "MKD \(path)", baseURL]
            if profile.protocolType == .ftps {
                args += ["--ftp-ssl", "--insecure"]
            }
        }

        let (_, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }
    }

    // MARK: - Delete

    static func deleteFile(profile: ConnectionProfile, path: String) async throws {
        let baseURL = buildURL(profile: profile, path: "/")
        var args: [String]

        if profile.protocolType == .sftp {
            args = ["-s", "--connect-timeout", "10", "--insecure", "-Q", "rm \(path)", baseURL]
        } else {
            args = ["-s", "--connect-timeout", "10", "-Q", "DELE \(path)", baseURL]
            if profile.protocolType == .ftps {
                args += ["--ftp-ssl", "--insecure"]
            }
        }

        let (_, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }
    }

    static func deleteDirectory(profile: ConnectionProfile, path: String) async throws {
        let baseURL = buildURL(profile: profile, path: "/")
        var args: [String]

        if profile.protocolType == .sftp {
            args = ["-s", "--connect-timeout", "10", "--insecure", "-Q", "rmdir \(path)", baseURL]
        } else {
            args = ["-s", "--connect-timeout", "10", "-Q", "RMD \(path)", baseURL]
            if profile.protocolType == .ftps {
                args += ["--ftp-ssl", "--insecure"]
            }
        }

        let (_, stderr, code) = try await runProcess(executable: curlPath, args: args)
        if code != 0 {
            throw mapCurlError(exitCode: code, stderr: stderr)
        }
    }

    // MARK: - Process Runner

    static func runProcess(executable: String, args: [String]) async throws -> (String, String, Int32) {
        try await withCheckedThrowingContinuation { cont in
            guard FileManager.default.fileExists(atPath: executable) else {
                cont.resume(throwing: FTPError.curlNotFound)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // waitUntilExit() is blocking, run on a background queue
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    process.waitUntilExit()
                    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let exitCode = process.terminationStatus
                    let log = "CMD: \(executable) \(args.joined(separator: " "))\nEXIT: \(exitCode)\nSTDOUT: \(stdout.prefix(500))\nSTDERR: \(stderr.prefix(200))\n---\n"
                    try? log.appendTo(url: URL(fileURLWithPath: "/tmp/ks-ftp-debug.log"))
                    cont.resume(returning: (stdout, stderr, exitCode))
                } catch {
                    let log = "LAUNCH ERROR: \(error) for \(executable)\n---\n"
                    try? log.appendTo(url: URL(fileURLWithPath: "/tmp/ks-ftp-debug.log"))
                    cont.resume(throwing: FTPError.curlNotFound)
                }
            }
        }
    }

    // MARK: - Error Mapping

    static func mapCurlError(exitCode: Int32, stderr: String) -> FTPError {
        switch exitCode {
        case 67: return .authenticationFailed
        case 9: return .permissionDenied
        case 78: return .fileNotFound
        case 7: return .connectionFailed("サーバーに接続できません")
        case 28: return .connectionFailed("接続がタイムアウトしました")
        case 35, 60: return .connectionFailed("SSL/TLS エラー")
        default:
            let msg = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .transferFailed(msg.isEmpty ? "終了コード: \(exitCode)" : msg)
        }
    }

    // MARK: - Directory Listing Parser

    static func parseDirectoryListing(output: String, basePath: String) -> [RemoteFile] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var files: [RemoteFile] = []

        for line in lines {
            guard !line.lowercased().hasPrefix("total") else { continue }
            if let file = parseUnixLine(line, basePath: basePath) {
                guard file.name != "." && file.name != ".." else { continue }
                files.append(file)
            }
        }

        return files.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // Parse a single line of Unix ls -la format output
    // Format: -rw-r--r--    1 user group 1234 Jan 15 10:30 filename
    private static func parseUnixLine(_ line: String, basePath: String) -> RemoteFile? {
        let parts = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
        guard parts.count >= 9 else { return nil }

        let permissions = String(parts[0])
        guard permissions.count >= 1,
              "-dlcbsp".contains(permissions.prefix(1)) else { return nil }

        let sizeStr = String(parts[4])
        let month = String(parts[5])
        let day = String(parts[6])
        let yearOrTime = String(parts[7])
        var name = String(parts[8]).trimmingCharacters(in: .whitespacesAndNewlines)

        let isSymlink = permissions.hasPrefix("l")
        if isSymlink, let arrowRange = name.range(of: " -> ") {
            name = String(name[name.startIndex..<arrowRange.lowerBound])
        }

        let isDirectory = permissions.hasPrefix("d")
        let size = Int64(sizeStr) ?? 0
        let filePath = basePath + name + (isDirectory ? "/" : "")
        let modifiedDate = parseDate(month: month, day: day, yearOrTime: yearOrTime)

        return RemoteFile(
            name: name,
            path: filePath,
            size: size,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            modifiedDate: modifiedDate,
            permissions: permissions
        )
    }

    private static func parseDate(month: String, day: String, yearOrTime: String) -> Date? {
        let months = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                      "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
        guard let monthNum = months[month.lowercased()],
              let dayNum = Int(day) else { return nil }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.month = monthNum
        comps.day = dayNum

        if yearOrTime.contains(":") {
            comps.year = cal.component(.year, from: Date())
            let tp = yearOrTime.split(separator: ":")
            comps.hour = tp.count > 0 ? Int(tp[0]) : nil
            comps.minute = tp.count > 1 ? Int(tp[1]) : nil
        } else {
            comps.year = Int(yearOrTime)
        }

        return cal.date(from: comps)
    }
}
