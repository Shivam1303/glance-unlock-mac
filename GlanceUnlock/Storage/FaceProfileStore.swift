import Foundation
import LocalAuthentication
import Security
import Vision

enum FaceProfileStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "\(message) (\(status))"
        case .invalidData:
            return "The saved face profile is invalid."
        }
    }
}

final class FaceProfileStore {
    private enum Backend {
        case dataProtection
        case legacy
    }

    private let service: String
    private let account: String
    private let featurePrintService: FeaturePrintService

    init(
        featurePrintService: FeaturePrintService = FeaturePrintService(),
        service: String = "com.glanceunlock.profile",
        account: String = "primary-face-profile"
    ) {
        self.featurePrintService = featurePrintService
        self.service = service
        self.account = account
    }

    func save(_ prints: [VNFeaturePrintObservation]) throws {
        let data = try featurePrintService.archive(prints)

        var status = upsert(data, in: .dataProtection)
        if status == errSecMissingEntitlement {
            // Local ad-hoc Xcode builds have no application-identifier access
            // group, which the Data Protection Keychain requires. The regular
            // macOS login Keychain is still encrypted and app access-controlled.
            status = upsert(data, in: .legacy)
        }
        guard status == errSecSuccess else { throw FaceProfileStoreError.unexpectedStatus(status) }
    }

    func load() throws -> [VNFeaturePrintObservation]? {
        for backend in [Backend.dataProtection, .legacy] {
            var item: CFTypeRef?
            let query = query(for: backend, disallowInteraction: true).merging([
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ]) { _, new in new }
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound || status == errSecMissingEntitlement { continue }
            guard status == errSecSuccess else { throw FaceProfileStoreError.unexpectedStatus(status) }
            guard let data = item as? Data else { throw FaceProfileStoreError.invalidData }
            return try featurePrintService.unarchive(data)
        }
        return nil
    }

    func delete() throws {
        var deletedItem = false
        for backend in [Backend.dataProtection, .legacy] {
            let status = SecItemDelete(query(for: backend, disallowInteraction: true) as CFDictionary)
            switch status {
            case errSecSuccess:
                deletedItem = true
            case errSecItemNotFound, errSecMissingEntitlement:
                continue
            default:
                throw FaceProfileStoreError.unexpectedStatus(status)
            }
        }
        guard deletedItem else { throw FaceProfileStoreError.unexpectedStatus(errSecItemNotFound) }
    }

    private func upsert(_ data: Data, in backend: Backend) -> OSStatus {
        let matchQuery = query(for: backend, disallowInteraction: true)
        let updateStatus = SecItemUpdate(
            matchQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        guard updateStatus == errSecItemNotFound else { return updateStatus }

        var addQuery = query(for: backend, disallowInteraction: false)
        addQuery[kSecValueData] = data
        if backend == .dataProtection {
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        return SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func query(for backend: Backend, disallowInteraction: Bool) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        if backend == .dataProtection {
            query[kSecUseDataProtectionKeychain] = true
        }
        if disallowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext] = context
        }
        return query
    }
}
