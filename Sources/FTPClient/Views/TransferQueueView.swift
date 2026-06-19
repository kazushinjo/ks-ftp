import SwiftUI

struct TransferQueueView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("転送キュー")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if appState.transfers.contains(where: { $0.isFinished }) {
                    Button("完了済みを削除") {
                        appState.clearFinishedTransfers()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if appState.transfers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("転送はありません")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.transfers) { item in
                    TransferRow(item: item)
                }
                .listStyle(.plain)
            }
        }
        .background(.windowBackground)
    }
}

private struct TransferRow: View {
    let item: TransferItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isUpload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                Text(item.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch item.status {
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.7)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .waiting:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconColor: Color {
        switch item.status {
        case .completed: return .green
        case .failed: return .red
        case .inProgress: return .accentColor
        case .waiting: return .secondary
        }
    }
}
