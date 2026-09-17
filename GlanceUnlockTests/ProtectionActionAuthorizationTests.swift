import LocalAuthentication
import XCTest
@testable import GlanceUnlock

@MainActor
final class ProtectionActionAuthorizationTests: XCTestCase {
    func testSuccessfulRequestsAuthenticateSeparately() async {
        var reasons: [String] = []
        let authorization = ProtectionActionAuthorization(authenticate: {
            reasons.append($0)
            return true
        }, reportError: { _ in XCTFail("Unexpected error") })
        for reason in ["pause", "quit"] {
            let finished = expectation(description: reason)
            authorization.request(reason: reason) { allowed in
                XCTAssertTrue(allowed)
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 2)
            XCTAssertFalse(authorization.isAuthenticating)
        }
        XCTAssertEqual(reasons, ["pause", "quit"])
    }

    func testFalseResultDoesNotAuthorizeAction() async {
        let authorization = ProtectionActionAuthorization(authenticate: { _ in false })
        let finished = expectation(description: "Denied")
        authorization.request(reason: "pause") { allowed in
            XCTAssertFalse(allowed)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
    }

    func testCancellationDoesNotAuthorizeOrShowError() async {
        let authorization = ProtectionActionAuthorization(authenticate: { _ in
            throw LAError(.userCancel)
        }, reportError: { _ in XCTFail("Cancellation should be silent") })
        let finished = expectation(description: "Cancelled")
        authorization.request(reason: "quit") { allowed in
            XCTAssertFalse(allowed)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertFalse(authorization.isAuthenticating)
    }

    func testFailureStaysClosedAndReportsError() async {
        var reported = false
        let authorization = ProtectionActionAuthorization(authenticate: { _ in
            throw LAError(.notInteractive)
        }, reportError: { _ in reported = true })
        let finished = expectation(description: "Failed")
        authorization.request(reason: "pause") { allowed in
            XCTAssertFalse(allowed)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertTrue(reported)
    }

    func testOverlappingRequestIsDenied() async {
        var calls = 0
        let authorization = ProtectionActionAuthorization(authenticate: { _ in
            calls += 1
            return true
        })
        let finished = expectation(description: "First request")
        authorization.request(reason: "pause") { allowed in
            XCTAssertTrue(allowed)
            finished.fulfill()
        }
        XCTAssertTrue(authorization.isAuthenticating)
        authorization.request(reason: "quit") { allowed in XCTAssertFalse(allowed) }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(calls, 1)
    }
}
