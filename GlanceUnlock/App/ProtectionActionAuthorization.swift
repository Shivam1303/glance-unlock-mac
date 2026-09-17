import AppKit
import Combine
import LocalAuthentication
import Security

/// Authorizes one action at a time; successful authentication is never cached.
@MainActor
final class ProtectionActionAuthorization: ObservableObject {
    static let shared = ProtectionActionAuthorization()

    @Published private(set) var isAuthenticating = false
    private let authenticate: @MainActor (String) async throws -> Bool
    private let reportError: @MainActor (Error) -> Void

    init(
        authenticate: @escaping @MainActor (String) async throws -> Bool = ProtectionActionAuthorization.requirePassword,
        reportError: @escaping @MainActor (Error) -> Void = { error in
            let alert = NSAlert()
            alert.messageText = "Authentication required"
            alert.informativeText = "Glance kept protection unchanged. \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    ) {
        self.authenticate = authenticate
        self.reportError = reportError
    }

    func request(reason: String, completion: @escaping @MainActor (Bool) -> Void) {
        guard !isAuthenticating else {
            completion(false)
            return
        }
        isAuthenticating = true
        // Defer presentation until the menu's tracking loop has closed.
        Task { @MainActor in
            await Task.yield()
            var authorized = false
            do {
                authorized = try await authenticate(reason)
            } catch {
                let cancelled = (error as? LAError).map {
                    [.userCancel, .systemCancel, .appCancel].contains($0.code)
                } ?? false
                if !cancelled { reportError(error) }
            }
            isAuthenticating = false
            completion(authorized)
        }
    }

    private static func requirePassword(reason: String) async throws -> Bool {
        var error: Unmanaged<CFError>?
        // A passcode constraint maps to the Mac account password. Do not use
        // deviceOwnerAuthentication, which also permits Touch ID / Apple Watch.
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .devicePasscode, &error
        ) else {
            throw error?.takeRetainedValue() as Error? ?? NSError(
                domain: "GlanceAuthorization", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The password prompt could not be created."]
            )
        }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        defer { context.invalidate() }
        return try await context.evaluateAccessControl(
            accessControl, operation: .useItem, localizedReason: reason
        )
    }
}
