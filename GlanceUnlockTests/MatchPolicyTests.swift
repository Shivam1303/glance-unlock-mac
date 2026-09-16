import XCTest
@testable import GlanceUnlock

final class MatchPolicyTests: XCTestCase {
    func testAcceptsBestThreeAverageAtThreshold() {
        let policy = MatchPolicy(threshold: 10)
        XCTAssertTrue(policy.matches([8, 9, 10, 80, 100]))
    }

    func testRejectsAboveThreshold() {
        let policy = MatchPolicy(threshold: 10)
        XCTAssertFalse(policy.matches([11, 12, 13, 1_000, 2_000]))
    }

    func testRequiresThreeEnrolledDistances() {
        XCTAssertNil(MatchPolicy().aggregate([1, 2]))
    }
}
