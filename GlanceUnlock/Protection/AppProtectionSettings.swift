import Combine
import Foundation

@MainActor
final class AppProtectionSettings: ObservableObject {
    private enum Key {
        static let enabled = "appProtection.enabled"
        static let protectedBundleIdentifiers = "appProtection.protectedBundleIdentifiers"
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? false
        protectedBundleIdentifiers = Set(defaults.stringArray(forKey: Key.protectedBundleIdentifiers) ?? [])
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
