import AppKit
import SwiftUI

struct RightClickHandler: NSViewRepresentable {
    let buildMenu: () -> NSMenu

    func makeNSView(context: Context) -> NSView { context.coordinator.view }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.buildMenu = buildMenu
    }
    func makeCoordinator() -> Coordinator { Coordinator(buildMenu: buildMenu) }

    class Coordinator: NSObject {
        let view = NSView()
        var buildMenu: () -> NSMenu
        private var monitor: Any?

        init(buildMenu: @escaping () -> NSMenu) {
            self.buildMenu = buildMenu
            super.init()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self else { return event }
                let pt = self.view.convert(event.locationInWindow, from: nil)
                if self.view.bounds.contains(pt) {
                    let menu = self.buildMenu()
                    guard menu.numberOfItems > 0 else { return event }
                    NSMenu.popUpContextMenu(menu, with: event, for: self.view)
                    return nil
                }
                return event
            }
        }

        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}

// NSMenuItem with a closure action.
// ActionHolder is retained via item.representedObject so target stays alive
// for the synchronous duration of NSMenu.popUpContextMenu.
func makeMenuItem(title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> NSMenuItem {
    let holder = ActionHolder(action)
    let item = NSMenuItem(title: title, action: #selector(ActionHolder.run), keyEquivalent: "")
    item.target = holder
    item.representedObject = holder
    if isDestructive {
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.systemRed]
        )
    }
    return item
}

private final class ActionHolder: NSObject {
    private let fn: () -> Void
    init(_ fn: @escaping () -> Void) { self.fn = fn }
    @objc func run() { fn() }
}
