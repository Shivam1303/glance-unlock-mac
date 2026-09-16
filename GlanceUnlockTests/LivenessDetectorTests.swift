import XCTest
@testable import GlanceUnlock

final class LivenessDetectorTests: XCTestCase {
    func testNaturalBlinkRequiresOpenClosedOpen() {
        var detector = LivenessDetector(confirmationFrames: 2, timeout: 5)
        XCTAssertEqual(detector.observe(eyeOpenness: 0.25), .waitingForOpen)
        XCTAssertEqual(detector.observe(eyeOpenness: 0.25), .waitingForClosed)
        XCTAssertEqual(detector.observe(eyeOpenness: 0.08), .waitingForClosed)
        XCTAssertEqual(detector.observe(eyeOpenness: 0.08), .waitingForReopen)
        for _ in 0..<2 { _ = detector.observe(eyeOpenness: 0.25) }
        XCTAssertEqual(detector.state, .passed)
    }

    func testOneBadFrameDoesNotCountAsBlink() {
        var detector = LivenessDetector(confirmationFrames: 3)
        for _ in 0..<3 { _ = detector.observe(eyeOpenness: 0.25) }
        _ = detector.observe(eyeOpenness: 0.08)
        _ = detector.observe(eyeOpenness: 0.25)
        XCTAssertEqual(detector.state, .waitingForClosed)
    }

    func testMissingFaceResetsChallenge() {
        var detector = LivenessDetector(confirmationFrames: 2)
        for _ in 0..<2 { _ = detector.observe(eyeOpenness: 0.25) }
        _ = detector.observe(eyeOpenness: nil)
        XCTAssertEqual(detector.state, .waitingForOpen)
    }

    func testTimeoutResetsChallenge() {
        var detector = LivenessDetector(confirmationFrames: 1, timeout: 1)
        let start = Date()
        _ = detector.observe(eyeOpenness: 0.25, now: start)
        _ = detector.observe(eyeOpenness: 0.08, now: start.addingTimeInterval(2))
        XCTAssertEqual(detector.state, .waitingForOpen)
    }
}
