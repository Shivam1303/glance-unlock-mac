import Combine
import Foundation

enum AppRelockTiming: String, CaseIterable, Identifiable {
    case immediately
    case afterThirtySeconds
    case whenAppQuits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .afterThirtySeconds: "After 30 seconds"
        case .whenAppQuits: "When the app quits"
        }
    }

    var detail: String {
        switch self {
        case .immediately: "Relock as soon as you switch away."
        case .afterThirtySeconds: "Keep the app unlocked for 30 seconds after you switch away."
        case .whenAppQuits: "Keep the app unlocked until you quit it. Switching apps or hiding it does not relock it."
        }
    }
}

@MainActor
final class AppProtectionSettings: ObservableObject {
    private enum Key {
        static let enabled = "appProtection.enabled"
        static let protectedBundleIdentifiers = "appProtection.protectedBundleIdentifiers"
        static let relockTiming = "appProtection.relockTiming"
    }

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    @Published private(set) var protectedBundleIdentifiers: Set<String> {
        didSet {
            defaults.set(protectedBundleIdentifiers.sorted(), forKey: Key.protectedBundleIdentifiers)
        }
    }

    @Published var relockTiming: AppRelockTiming {
        didSet { defaults.set(relockTiming.rawValue, forKey: Key.relockTiming) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? false
        protectedBundleIdentifiers = Set(defaults.stringArray(forKey: Key.protectedBundleIdentifiers) ?? [])
        relockTiming = AppRelockTiming(rawValue: defaults.string(forKey: Key.relockTiming) ?? "") ?? .immediately
    }

    var protectedAppCount: Int { protectedBundleIdentifiers.count }

    func isProtected(_ bundleIdentifier: String) -> Bool {
        protectedBundleIdentifiers.contains(bundleIdentifier)
    }

    func setProtected(_ protected: Bool, bundleIdentifier: String) {
        if protected {
            protectedBundleIdentifiers.insert(bundleIdentifier)
        } else {
            protectedBundleIdentifiers.remove(bundleIdentifier)
        }
    }
}
