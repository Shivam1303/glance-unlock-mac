import XCTest
@testable import GlanceUnlock

@MainActor
final class AppProtectionSettingsTests: XCTestCase {
    func testRelockTimingDefaultsToImmediately() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppProtectionSettings(defaults: defaults)

        XCTAssertEqual(settings.relockTiming, .immediately)
    }

    func testRelockTimingPersists() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppProtectionSettings(defaults: defaults)
        settings.relockTiming = .whenAppQuits

        XCTAssertEqual(AppProtectionSettings(defaults: defaults).relockTiming, .whenAppQuits)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "com.glanceunlock.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
