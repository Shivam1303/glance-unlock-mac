import AppKit
import SwiftUI

@MainActor
final class ApplicationProtectionController: NSObject {
    private let settings: AppProtectionSettings
    private let camera: CameraService
    private let store: FaceProfileStore
    private let featurePrintService: FeaturePrintService
    private var gateWindow: ProtectionWindow?
    private var gatedApplication: NSRunningApplication?
    private var gatedBundleIdentifier: String?
    private var gatedProcessIdentifier: Int32?
    private var authorizations = AppAuthorizationSessions()
    private var lastAccessibleApplication: NSRunningApplication?
    private var applicationToReturnTo: NSRunningApplication?
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
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
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
        clearAuthorization()
        dismissGate(restoreApplication: true)
    }

    func configurationDidChange() {
        if let bundleIdentifier = gatedBundleIdentifier,
           !settings.isEnabled || !settings.isProtected(bundleIdentifier) {
            dismissGate(restoreApplication: true)
        }
        relockAuthorizedApplicationIfNeeded(for: NSWorkspace.shared.frontmostApplication)
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

        pendingGlanceAuthorizationReset = false

        // The shield belongs only to its target app. Let Command-Tab, the Dock,
        // and other app activations leave the gate without granting access.
        if let gatedProcessIdentifier, gatedProcessIdentifier != application.processIdentifier {
            leaveGate(activatePreviousApplication: false)
        }

        if isReturningToAuthenticatedApplication {
            isReturningToAuthenticatedApplication = false
        }

        relockAuthorizedApplicationIfNeeded(for: application)

        if !settings.isEnabled || !settings.isProtected(bundleIdentifier) || isAuthorized(application) {
            lastAccessibleApplication = application
        }

        guard settings.isEnabled,
              settings.isProtected(bundleIdentifier),
              !isAuthorized(application),
              camera.frameHandler == nil,
              gateWindow == nil else { return }

        presentGate(for: application, bundleIdentifier: bundleIdentifier)
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        clearAuthorization()
        dismissGate(restoreApplication: true)
    }

    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        authorizations.didTerminate(processIdentifier: application.processIdentifier)

        if let gatedProcessIdentifier,
           application.processIdentifier == gatedProcessIdentifier {
            dismissGate(restoreApplication: false)
        }
    }

    private func presentGate(for application: NSRunningApplication, bundleIdentifier: String) {
        gatedApplication = application
        gatedBundleIdentifier = bundleIdentifier
        gatedProcessIdentifier = application.processIdentifier
        applicationToReturnTo = lastAccessibleApplication
        let identity = ApplicationIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: application.processIdentifier
        )

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
            onAuthenticated: { [weak self] in self?.authenticationSucceeded(for: identity) },
            onLeave: { [weak self] in
                guard self?.gatedProcessIdentifier == identity.processIdentifier else { return }
                self?.leaveGate()
            }
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
        window.onLeave = { [weak self] in self?.leaveGate() }
        // A non-activating panel accepts interaction without making Glance the
        // foreground app. The protected app stays active behind this opaque
        // overlay, so unlocking requires no fragile cross-app focus reversal.
        gateWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func authenticationSucceeded(for identity: ApplicationIdentity) {
        // A cancelled macOS authentication request can complete after another
        // gate opens. It must not authenticate the new target.
        guard gatedBundleIdentifier == identity.bundleIdentifier,
              gatedProcessIdentifier == identity.processIdentifier else { return }
        authorizations.authorize(identity)
        lastAccessibleApplication = gatedApplication
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

            self.relockAuthorizedApplicationIfNeeded(for: NSWorkspace.shared.frontmostApplication)
        }
    }

    private func isAuthorized(_ application: NSRunningApplication) -> Bool {
        guard let identity = identity(of: application) else { return false }
        return authorizations.isAuthorized(identity)
    }

    private func relockAuthorizedApplicationIfNeeded(for activeApplication: NSRunningApplication?) {
        authorizations.didActivate(activeApplication.flatMap(identity(of:)), timing: settings.relockTiming)
    }

    private func identity(of application: NSRunningApplication) -> ApplicationIdentity? {
        guard let bundleIdentifier = application.bundleIdentifier else { return nil }
        return ApplicationIdentity(bundleIdentifier: bundleIdentifier, processIdentifier: application.processIdentifier)
    }

    private func clearAuthorization() {
        authorizations.removeAll()
    }

    private func leaveGate(activatePreviousApplication: Bool = true) {
        guard gateWindow != nil else { return }
        let previousApplication = applicationToReturnTo
        // Leaving the shield must not reveal the unauthenticated app beneath it.
        _ = gatedApplication?.hide()
        isReturningToAuthenticatedApplication = false
        dismissGate(restoreApplication: false)

        guard activatePreviousApplication else { return }
        let destination = previousApplication.flatMap { $0.isTerminated ? nil : $0 }
            ?? NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }
        _ = destination?.unhide()
        _ = destination?.activate(options: [.activateAllWindows])
    }

    private func dismissGate(restoreApplication: Bool) {
        let application = gatedApplication
        gateWindow?.orderOut(nil)
        gateWindow?.close()
        gateWindow = nil
        gatedApplication = nil
        gatedBundleIdentifier = nil
        gatedProcessIdentifier = nil
        applicationToReturnTo = nil
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
        // One focus handoff is sufficient; queued retries could pull focus back
        // after the user has chosen to switch to a different app.
        _ = application.unhide()
        _ = application.activate(options: [.activateAllWindows])
    }

    private func screenUnderPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}

private final class ProtectionWindow: NSPanel {
    var onLeave: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onLeave?() }
    override func performClose(_ sender: Any?) { onLeave?() }
}
