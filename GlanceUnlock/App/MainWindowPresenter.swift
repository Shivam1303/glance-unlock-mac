import AppKit
import Combine
import SwiftUI

@MainActor
final class MainWindowPresenter {
    private weak var window: NSWindow?
    private var windowCloseObserver: AnyCancellable?
    private var presentationRequested = false

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
                    }
                }
        }
        DispatchQueue.main.async { [weak self] in
            self?.presentIfRequested()
        }
    }

    private func presentIfRequested() {
        guard presentationRequested, let window else { return }
        presentationRequested = false

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        // Menu-bar-only apps can otherwise order beneath the foreground app.
        window.orderFrontRegardless()
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
