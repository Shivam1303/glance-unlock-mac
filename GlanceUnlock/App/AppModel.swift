import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
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

    func refreshProfile() {
        do { hasProfile = try profileStore.load() != nil }
        catch { errorMessage = "The local face profile could not be read." }
    }
}
