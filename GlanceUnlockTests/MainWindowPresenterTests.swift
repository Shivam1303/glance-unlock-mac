import AppKit
import XCTest
@testable import GlanceUnlock

@MainActor
final class MainWindowPresenterTests: XCTestCase {
    func testSceneOpeningIsDeferredUntilMenuActionReturns() async {
        let presenter = MainWindowPresenter()
        var sceneOpened = false

        presenter.show { sceneOpened = true }

        XCTAssertFalse(sceneOpened)
        await drainMainQueue()
        XCTAssertTrue(sceneOpened)
    }

    func testOpeningWaitsForNewSceneWindowToAttach() async {
        let presenter = MainWindowPresenter()
        presenter.show {}
        await drainMainQueue()

        let window = makeWindow()
        defer { window.close() }
        XCTAssertFalse(window.isVisible)

        presenter.register(window)
        await drainMainQueue()

        XCTAssertTrue(window.isVisible)
    }

    func testReopeningRestoresClosedMainWindowWithoutShowingOtherWindows() async {
        let presenter = MainWindowPresenter()
        let mainWindow = makeWindow()
        let reopenedWindow = makeWindow()
        let unrelatedWindow = makeWindow()
        defer {
            mainWindow.close()
            reopenedWindow.close()
            unrelatedWindow.close()
        }
        presenter.register(mainWindow)
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.close()
        XCTAssertFalse(mainWindow.isVisible)

        presenter.show { presenter.register(reopenedWindow) }
        await drainMainQueue()

        XCTAssertTrue(reopenedWindow.isVisible)
        XCTAssertFalse(mainWindow.isVisible)
        XCTAssertFalse(unrelatedWindow.isVisible)
    }

    func testOpeningRestoresMinimizedWindow() async {
        let presenter = MainWindowPresenter()
        let window = makeWindow()
        defer { window.close() }
        presenter.register(window)
        window.makeKeyAndOrderFront(nil)
        window.miniaturize(nil)
        await waitForWindowState { window.isMiniaturized }
        XCTAssertTrue(window.isMiniaturized)

        presenter.show {}
        await waitForWindowState { !window.isMiniaturized && window.isVisible }

        XCTAssertFalse(window.isMiniaturized)
        XCTAssertTrue(window.isVisible)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 320, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        return window
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func waitForWindowState(_ condition: () -> Bool) async {
        // AppKit completes Dock minimization on a later run-loop turn.
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
