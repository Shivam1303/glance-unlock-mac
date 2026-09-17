import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        refresh()
    }

    func refresh() {
        errorMessage = nil
        switch service.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = true
            requiresApproval = true
        case .notRegistered:
            isEnabled = false
            requiresApproval = false
        case .notFound:
            // Service Management reports `.notFound` until it has seen this
            // main-app service at least once. It is a normal initial state,
            // and `register()` is what creates the registration.
            isEnabled = false
            requiresApproval = false
        @unknown default:
            isEnabled = false
            requiresApproval = false
            errorMessage = "macOS returned an unknown Login Item status."
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                // A first-time main-app registration commonly begins at
                // `.notFound`, rather than `.notRegistered`.
                guard service.status == .notRegistered || service.status == .notFound else {
                    refresh()
                    return
                }
                try service.register()
            } else {
                guard service.status == .enabled || service.status == .requiresApproval else {
                    refresh()
                    return
                }
                try service.unregister()
            }
            refresh()
        } catch {
            refresh()
            errorMessage = enabled
                ? "Launch at Login could not be enabled. Install a signed build in Applications, then try again. \(error.localizedDescription)"
                : "Launch at Login could not be disabled. \(error.localizedDescription)"
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
