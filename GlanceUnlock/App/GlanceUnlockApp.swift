import AppKit
import SwiftUI

final class GlanceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // A synchronous denial must return terminateCancel rather than replying
        // before AppKit has registered a pending termination request.
        guard !ProtectionActionAuthorization.shared.isAuthenticating else { return .terminateCancel }
        ProtectionActionAuthorization.shared.request(reason: "quit Glance and stop app protection") { authorized in
            sender.reply(toApplicationShouldTerminate: authorized)
        }
        return .terminateLater
    }

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
                .background(MainWindowRegistration(presenter: model.mainWindowPresenter))
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(model.hasProfile ? .suppressed : .presented)

        MenuBarExtra {
            GlanceMenuBarView()
                .environmentObject(model)
        } label: {
            Image("MenuBarLogo")
                .renderingMode(.original)
                .opacity(model.protectionSettings.isEnabled ? 1 : 0.55)
                .accessibilityLabel(model.protectionSettings.isEnabled ? "Glance protection active" : "Glance protection paused")
        }
        .menuBarExtraStyle(.menu)
    }
}
