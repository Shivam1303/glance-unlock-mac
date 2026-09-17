import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let actionAuthorization = ProtectionActionAuthorization.shared
    let mainWindowPresenter = MainWindowPresenter()
    let camera = CameraService()
    let profileStore: FaceProfileStore
    let featurePrintService = FeaturePrintService()
    let protectionSettings: AppProtectionSettings
    let applicationCatalog: ApplicationCatalog
    let launchAtLogin: LaunchAtLoginController
    private var protectionController: ApplicationProtectionController?
    private var cancellables = Set<AnyCancellable>()
    @Published var hasProfile = false
    @Published var isSafeLockPresented = false
    @Published var isProtectionSettingsPresented = false
    @Published var errorMessage: String?

    init(profileStore: FaceProfileStore = FaceProfileStore()) {
        self.profileStore = profileStore
        protectionSettings = AppProtectionSettings()
        applicationCatalog = ApplicationCatalog()
        launchAtLogin = LaunchAtLoginController()
        do { hasProfile = try profileStore.load() != nil }
        catch { errorMessage = "The local face profile could not be read." }

        let controller = ApplicationProtectionController(
            settings: protectionSettings,
            camera: camera,
            store: profileStore,
            featurePrintService: featurePrintService
        )
        controller.start()
        protectionController = controller

        // Relay nested settings changes so the menu-bar icon and menu content
        // update immediately when protection is paused or resumed elsewhere.
        protectionSettings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func startProtectionMonitoring() {
        guard protectionController == nil else { return }
        let controller = ApplicationProtectionController(
            settings: protectionSettings,
            camera: camera,
            store: profileStore,
            featurePrintService: featurePrintService
        )
        controller.start()
        protectionController = controller
    }

    func protectionConfigurationDidChange() {
        protectionController?.configurationDidChange()
    }

    func setProtectionEnabled(_ enabled: Bool) {
        guard enabled != protectionSettings.isEnabled else { return }
        guard !actionAuthorization.isAuthenticating else { return }
        if enabled {
            protectionSettings.isEnabled = true
            protectionConfigurationDidChange()
            return
        }
        actionAuthorization.request(reason: "pause app protection") { [weak self] authorized in
            guard authorized, let self else { return }
            protectionSettings.isEnabled = false
            protectionConfigurationDidChange()
        }
    }

    func setAppProtected(_ protected: Bool, bundleIdentifier: String) {
        guard !actionAuthorization.isAuthenticating else { return }
        if protected {
            protectionSettings.setProtected(true, bundleIdentifier: bundleIdentifier)
            protectionConfigurationDidChange()
            return
        }
        actionAuthorization.request(reason: "remove protection for this app") { [weak self] authorized in
            guard authorized, let self else { return }
            protectionSettings.setProtected(false, bundleIdentifier: bundleIdentifier)
            protectionConfigurationDidChange()
        }
    }

    func refreshProfile() {
        do { hasProfile = try profileStore.load() != nil }
        catch { errorMessage = "The local face profile could not be read." }
    }
}
