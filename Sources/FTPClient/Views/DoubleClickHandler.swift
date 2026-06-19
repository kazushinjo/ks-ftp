import AppKit
import SwiftUI

/// NSEvent ローカルモニターでテーブル上のダブルクリックを確実に検出する
struct DoubleClickHandler: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleClick: onDoubleClick)
    }

    class Coordinator: NSObject {
        let view = NSView()
        var onDoubleClick: () -> Void
        private var monitor: Any?

        init(onDoubleClick: @escaping () -> Void) {
            self.onDoubleClick = onDoubleClick
            super.init()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, event.clickCount == 2 else { return event }
                guard let window = self.view.window else { return event }
                let pt = self.view.convert(event.locationInWindow, from: nil)
                if self.view.bounds.contains(pt) {
                    self.onDoubleClick()
                }
                return event   // イベントはそのまま流してTableの選択も維持
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
