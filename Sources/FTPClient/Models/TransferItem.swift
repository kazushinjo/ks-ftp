import Foundation

enum TransferStatus {
    case waiting
    case inProgress
    case completed
    case failed(Error)
}

struct TransferItem: Identifiable {
    let id = UUID()
    let name: String
    let isUpload: Bool
    var progress: Double = 0
    var status: TransferStatus = .waiting

    var statusText: String {
        switch status {
        case .waiting: return "待機中"
        case .inProgress: return isUpload ? "アップロード中..." : "ダウンロード中..."
        case .completed: return "完了"
        case .failed(let err): return "エラー: \(err.localizedDescription)"
        }
    }

    var isFinished: Bool {
        switch status {
        case .completed, .failed: return true
        default: return false
        }
    }
}
