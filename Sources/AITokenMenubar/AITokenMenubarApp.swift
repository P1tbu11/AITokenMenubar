import AppKit
import Combine
import SwiftUI

@main
struct AITokenMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let service = QuotaService()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AI Token")
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(service: service))

        // Observe menuBarText changes to update the status item button
        service.$menuBarText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                guard let button = self?.statusItem.button else { return }
                if text.isEmpty {
                    button.title = ""
                    button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AI Token")
                    button.imagePosition = .imageOnly
                } else {
                    button.image = nil
                    button.title = text
                    button.imagePosition = .noImage
                    button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Refresh data when popover opens
            Task { @MainActor in
                await service.fetchQuota()
            }
        }
    }
}
