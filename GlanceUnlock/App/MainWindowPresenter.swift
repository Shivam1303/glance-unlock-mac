import AppKit
import Combine
import SwiftUI

@MainActor
final class MainWindowPresenter {
    private weak var window: NSWindow?
    private var windowCloseObserver: AnyCancellable?
    private var presentationRequested = false
    private var activationObserver: AnyCancellable?
    private let isApplicationActive: @MainActor () -> Bool
    private let activateApplication: @MainActor () -> Void

    init(
        isApplicationActive: @escaping @MainActor () -> Bool = { NSApplication.shared.isActive },
        activateApplication: @escaping @MainActor () -> Void = {
            // This is an explicit menu action: bring Glance forward even when
            // another app owns the foreground.
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    ) {
        self.isApplicationActive = isApplicationActive
        self.activateApplication = activateApplication
        activationObserver = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification, object: NSApplication.shared)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.finishPresentationIfActive()
                }
            }
    }

    func show(openScene: @escaping @MainActor () -> Void) {
        // Wait until the menu finishes tracking before opening and activating
        // the scene. A new scene may attach its NSWindow later in the run loop.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentationRequested = true
            openScene()
            self.presentIfRequested()
        }
    }

    func register(_ window: NSWindow) {
        if self.window !== window {
            self.window = window
            windowCloseObserver = NotificationCenter.default
                .publisher(for: NSWindow.willCloseNotification, object: window)
                .sink { [weak self] _ in
                    // AppKit closes windows on the main thread. Release the
                    // scene reference so the next request waits for its new window.
                    MainActor.assumeIsolated {
                        self?.window = nil
                        self?.windowCloseObserver = nil
                        self?.presentationRequested = false
                    }
                }
        }
        DispatchQueue.main.async { [weak self] in
            self?.presentIfRequested()
        }
    }

    private func presentIfRequested() {
        guard presentationRequested, let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApplication.shared.unhide(nil)
        // A window on another Space should follow this explicit menu request.
        let originalBehavior = window.collectionBehavior
        window.collectionBehavior = originalBehavior.union(.moveToActiveSpace).subtracting(.canJoinAllSpaces)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.collectionBehavior = originalBehavior
        activateApplication()
        finishPresentationIfActive()
    }

    private func finishPresentationIfActive() {
        guard presentationRequested, isApplicationActive(), let window else { return }
        // Activation is asynchronous. Focus again after it completes, and keep
        // an existing settings/enrollment sheet as the keyboard destination.
        presentationRequested = false
        let destination = window.attachedSheet ?? window
        destination.makeKeyAndOrderFront(nil)
        destination.orderFrontRegardless()
    }
}

struct MainWindowRegistration: NSViewRepresentable {
    let presenter: MainWindowPresenter

    func makeNSView(context: Context) -> RegistrationView {
        let view = RegistrationView()
        view.presenter = presenter
        return view
    }

    func updateNSView(_ view: RegistrationView, context: Context) {
        view.presenter = presenter
        if let window = view.window {
            presenter.register(window)
        }
    }

    final class RegistrationView: NSView {
        weak var presenter: MainWindowPresenter?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                presenter?.register(window)
            }
        }
    }
}
