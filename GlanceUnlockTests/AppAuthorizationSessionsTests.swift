import XCTest
@testable import GlanceUnlock

final class AppAuthorizationSessionsTests: XCTestCase {
    private let first = ApplicationIdentity(bundleIdentifier: "com.example.first", processIdentifier: 100)
    private let second = ApplicationIdentity(bundleIdentifier: "com.example.second", processIdentifier: 200)
    private let start = Date(timeIntervalSince1970: 1_000)

    func testQuitOnlySessionsSurviveSwitchingAndUnlockingAnotherApp() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(second, timing: .whenAppQuits, at: start)
        sessions.authorize(second)
        sessions.didActivate(first, timing: .whenAppQuits, at: start.addingTimeInterval(3_600))

        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(3_600)))
        XCTAssertTrue(sessions.isAuthorized(second, at: start.addingTimeInterval(3_600)))
    }

    func testQuitOnlySessionSurvivesLeavingForGlanceOrHiding() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(nil, timing: .whenAppQuits, at: start)
        sessions.didActivate(second, timing: .whenAppQuits, at: start.addingTimeInterval(60))

        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(3_600)))
    }

    func testQuittingRevokesOnlyThatAppAndRelaunchRequiresVerification() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.authorize(second)
        sessions.didTerminate(processIdentifier: first.processIdentifier)
        let relaunched = ApplicationIdentity(bundleIdentifier: first.bundleIdentifier, processIdentifier: 101)

        XCTAssertFalse(sessions.isAuthorized(first))
        XCTAssertFalse(sessions.isAuthorized(relaunched))
        XCTAssertTrue(sessions.isAuthorized(second))
    }

    func testImmediateTimingRevokesSessionOnFocusChange() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(second, timing: .immediately, at: start)

        XCTAssertFalse(sessions.isAuthorized(first, at: start))
    }

    func testBackgroundSwitchesDoNotExtendThirtySecondGracePeriod() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(second, timing: .afterThirtySeconds, at: start)
        sessions.didActivate(nil, timing: .afterThirtySeconds, at: start.addingTimeInterval(20))

        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(29)))
        sessions.didActivate(first, timing: .afterThirtySeconds, at: start.addingTimeInterval(30))
        XCTAssertFalse(sessions.isAuthorized(first, at: start.addingTimeInterval(30)))
    }

    func testReturningWithinGracePeriodCancelsCountdown() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(second, timing: .afterThirtySeconds, at: start)
        sessions.didActivate(first, timing: .afterThirtySeconds, at: start.addingTimeInterval(20))

        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(100)))
        sessions.didActivate(second, timing: .afterThirtySeconds, at: start.addingTimeInterval(100))
        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(129)))
        XCTAssertFalse(sessions.isAuthorized(first, at: start.addingTimeInterval(130)))
    }

    func testSwitchingToQuitOnlyTimingCancelsPendingExpiry() {
        var sessions = AppAuthorizationSessions()
        sessions.authorize(first)
        sessions.didActivate(second, timing: .afterThirtySeconds, at: start)
        sessions.didActivate(second, timing: .whenAppQuits, at: start.addingTimeInterval(10))

        XCTAssertTrue(sessions.isAuthorized(first, at: start.addingTimeInterval(100)))
    }
}
