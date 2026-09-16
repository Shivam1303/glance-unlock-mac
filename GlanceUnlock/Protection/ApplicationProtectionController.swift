import AppKit
import SwiftUI

@MainActor
final class ApplicationProtectionController: NSObject {
    private let settings: AppProtectionSettings
    private let camera: CameraService
    private let store: FaceProfileStore
    private let featurePrintService: FeaturePrintService
    private var gateWindow: ProtectionWindow?
    private weak var gatedApplication: NSRunningApplication?
    private var gatedBundleIdentifier: String?
    private var authorizedBundleIdentifier: String?
    private var lastExternalBundleIdentifier: String?
    private var isReturningToAuthenticatedApplication = false
    private var pendingGlanceAuthorizationReset = false
    private var isMonitoring = false

    init(
        settings: AppProtectionSettings,
        camera: CameraService,
        store: FaceProfileStore,
        featurePrintService: FeaturePrintService
    ) {
        self.settings = settings
        self.camera = camera
        self.store = store
        self.featurePrintService = featurePrintService
        super.init()
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        dismissGate(restoreApplication: true)
    }

    func configurationDidChange() {
        guard let bundleIdentifier = gatedBundleIdentifier else { return }
        if !settings.isEnabled || !settings.isProtected(bundleIdentifier) {
            dismissGate(restoreApplication: true)
        }
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = application.bundleIdentifier else { return }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        if bundleIdentifier == ownBundleIdentifier {
            // Activating Glance as part of presenting its gate must not revoke
            // the pending session. The activation notification can arrive
            // after the gate closes, so keep ignoring it until focus has been
            // handed back to the app that was just authenticated.
            guard gateWindow == nil && !isReturningToAuthenticatedApplication else { return }
            deferAuthorizationResetWhileFocusSettles()
            return
        }
        guard application.activationPolicy == .regular else { return }

        // If Glance genuinely became active between two visits to an app,
        // revoke the previous visit before evaluating the new activation.
        if pendingGlanceAuthorizationReset {
            pendingGlanceAuthorizationReset = false
            authorizedBundleIdentifier = nil
            lastExternalBundleIdentifier = nil
        }

        if isReturningToAuthenticatedApplication {
            if bundleIdentifier == authorizedBundleIdentifier {
                lastExternalBundleIdentifier = bundleIdentifier
                isReturningToAuthenticatedApplication = false
                return
            }
            isReturningToAuthenticatedApplication = false
        }

        if lastExternalBundleIdentifier != bundleIdentifier {
            authorizedBundleIdentifier = nil
            lastExternalBundleIdentifier = bundleIdentifier
        }

        guard settings.isEnabled,
              settings.isProtected(bundleIdentifier),
              authorizedBundleIdentifier != bundleIdentifier,
              camera.frameHandler == nil,
              gateWindow == nil else { return }

        presentGate(for: application, bundleIdentifier: bundleIdentifier)
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        dismissGate(restoreApplication: true)
    }

    private func presentGate(for application: NSRunningApplication, bundleIdentifier: String) {
        gatedApplication = application
        gatedBundleIdentifier = bundleIdentifier

        let appName = application.localizedName ?? "Protected app"
        let appIcon = application.icon ?? NSWorkspace.shared.icon(forFile: application.bundleURL?.path ?? "")
        let screen = screenUnderPointer() ?? NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1100, height: 720)

        let rootView = AppUnlockGateView(
            applicationName: appName,
            applicationIcon: appIcon,
            camera: camera,
            store: store,
            featurePrintService: featurePrintService,
            onAuthenticated: { [weak self] in self?.authenticationSucceeded() }
        )

        let window = ProtectionWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.contentViewController = NSHostingController(rootView: rootView)
        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.setFrame(frame, display: true)
        // A non-activating panel accepts interaction without making Glance the
        // foreground app. The protected app stays active behind this opaque
        // overlay, so unlocking requires no fragile cross-app focus reversal.
        gateWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func authenticationSucceeded() {
        guard let bundleIdentifier = gatedBundleIdentifier else {
            dismissGate(restoreApplication: false)
            return
        }
        authorizedBundleIdentifier = bundleIdentifier
        isReturningToAuthenticatedApplication = true
        dismissGate(restoreApplication: true)
    }

    private func deferAuthorizationResetWhileFocusSettles() {
        pendingGlanceAuthorizationReset = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.pendingGlanceAuthorizationReset else { return }
            self.pendingGlanceAuthorizationReset = false

            // A late Glance activation notification is part of closing the
            // gate if the protected app already owns the foreground again.
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,
                  self.gateWindow == nil,
                  !self.isReturningToAuthenticatedApplication else { return }

            self.authorizedBundleIdentifier = nil
            self.lastExternalBundleIdentifier = nil
        }
    }

    private func dismissGate(restoreApplication: Bool) {
        let application = gatedApplication
        gateWindow?.orderOut(nil)
        gateWindow?.close()
        gateWindow = nil
        gatedApplication = nil
        gatedBundleIdentifier = nil
        camera.frameHandler = nil
        camera.stop()

        guard restoreApplication, let application, !application.isTerminated else {
            if restoreApplication {
                isReturningToAuthenticatedApplication = false
            }
            return
        }

        // With the non-activating gate the target normally remained active the
        // entire time. In that common path, closing the panel is the complete
        // handoff and Glance never enters the foreground.
        if application.isActive && !application.isHidden {
            isReturningToAuthenticatedApplication = false
            return
        }
        handOffFocus(to: application)
    }

    private func handOffFocus(to application: NSRunningApplication, attempt: Int = 0) {
        guard !application.isTerminated else {
            isReturningToAuthenticatedApplication = false
            return
        }

        _ = application.unhide()

        let delay = attempt == 0 ? 0.06 : 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak application] in
            guard let self, let application, !application.isTerminated else {
                self?.isReturningToAuthenticatedApplication = false
                return
            }

            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                return
            }

            _ = application.unhide()
            _ = application.activate(options: [.activateAllWindows])

            if attempt < 3 {
                self.handOffFocus(to: application, attempt: attempt + 1)
            } else {
                self.openApplicationAsActivationFallback(application)
            }
        }
    }

    private func openApplicationAsActivationFallback(_ application: NSRunningApplication) {
        guard let bundleURL = application.bundleURL else {
            isReturningToAuthenticatedApplication = false
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(
            at: bundleURL,
            configuration: configuration,
            completionHandler: nil
        )
    }

    private func screenUnderPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}

private final class ProtectionWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // The gate may only be closed by its controller after authentication or
    // an explicit protection configuration/lifecycle change.
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
}
