import AppKit
import Combine

struct ProtectedApplication: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String
    let bundleURL: URL

    var id: String { bundleIdentifier }

    @MainActor var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        image.size = NSSize(width: 40, height: 40)
        return image
    }
}

@MainActor
final class ApplicationCatalog: ObservableObject {
    @Published private(set) var applications: [ProtectedApplication] = []
    @Published private(set) var isRefreshing = false

    private let excludedBundleIdentifiers: Set<String> = [
        Bundle.main.bundleIdentifier ?? "com.glanceunlock.prototype",
        "com.apple.loginwindow",
        "com.apple.dock",
        "com.apple.systemuiserver"
    ]

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        var candidates: [String: ProtectedApplication] = [:]
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                addApplication(at: url, to: &candidates)
            }
        }

        // Include ordinary apps launched from non-standard locations, such as
        // a developer build folder or an external volume.
        for application in NSWorkspace.shared.runningApplications where application.activationPolicy == .regular {
            if let url = application.bundleURL {
                addApplication(at: url, to: &candidates)
            }
        }

        applications = candidates.values.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        isRefreshing = false
    }

    private func addApplication(
        at url: URL,
        to candidates: inout [String: ProtectedApplication]
    ) {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !excludedBundleIdentifiers.contains(bundleIdentifier),
              bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool != true,
              bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool != true else { return }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        guard !displayName.isEmpty else { return }
        candidates[bundleIdentifier] = ProtectedApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            bundleURL: url
        )
    }
}
