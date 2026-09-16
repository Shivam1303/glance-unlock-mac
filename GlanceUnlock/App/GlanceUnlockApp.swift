import AppKit
import SwiftUI

final class GlanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct GlanceUnlockApp: App {
    @NSApplicationDelegateAdaptor(GlanceAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Glance Unlock", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 860, idealWidth: 1080, minHeight: 660, idealHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(model.hasProfile ? .suppressed : .presented)

        MenuBarExtra {
            GlanceMenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.protectionSettings.isEnabled ? "faceid" : "face.dashed")
                .accessibilityLabel(model.protectionSettings.isEnabled ? "Glance protection active" : "Glance protection paused")
        }
        .menuBarExtraStyle(.menu)
    }
}
