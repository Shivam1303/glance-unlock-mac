import AppKit
import SwiftUI

struct GlanceMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Text(statusTitle)

        Button("Open Glance") {
            showMainWindow()
        }

        Button("Protected Apps…") {
            model.isProtectionSettingsPresented = true
            showMainWindow()
        }

        Divider()

        Button(model.protectionSettings.isEnabled ? "Pause Protection" : "Resume Protection") {
            model.protectionSettings.isEnabled.toggle()
            model.protectionConfigurationDidChange()
        }
        .disabled(model.protectionSettings.protectedAppCount == 0)

        Text("\(model.protectionSettings.protectedAppCount) protected \(model.protectionSettings.protectedAppCount == 1 ? "app" : "apps")")

        Divider()

        Button("Quit Glance") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusTitle: String {
        guard model.protectionSettings.protectedAppCount > 0 else { return "No protected apps" }
        return model.protectionSettings.isEnabled ? "Protection active" : "Protection paused"
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate()
    }
}
