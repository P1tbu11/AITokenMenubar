import AppKit
import SwiftUI

@main
struct AITokenMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var service = QuotaService()

    var body: some Scene {
        MenuBarExtra {
            ContentView(service: service)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if service.isAuthenticated, service.displayPercent > 0 {
            let pct = Int(service.displayPercent.rounded())
            Text(pct > 0 ? "\(pct)%" : "AI")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        } else {
            Image(systemName: "cpu")
                .font(.system(size: 12))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
