import Foundation

struct ApplicationIdentity: Hashable {
    let bundleIdentifier: String
    let processIdentifier: Int32
}

/// Verified sessions belong to individual running apps, rather than to the
/// most recently verified app. Focus changes never revoke a quit-only session.
struct AppAuthorizationSessions {
    private struct Authorization {
        var expiresAt: Date?
    }

    private var authorizations: [ApplicationIdentity: Authorization] = [:]

    mutating func authorize(_ application: ApplicationIdentity) {
        authorizations[application] = Authorization()
    }

    func isAuthorized(_ application: ApplicationIdentity, at date: Date = Date()) -> Bool {
        guard let authorization = authorizations[application] else { return false }
        return authorization.expiresAt.map { date < $0 } ?? true
    }

    mutating func didActivate(
        _ application: ApplicationIdentity?,
        timing: AppRelockTiming,
        at date: Date = Date()
    ) {
        for identity in Array(authorizations.keys) {
            guard var authorization = authorizations[identity] else { continue }
            if let expiry = authorization.expiresAt, date >= expiry {
                authorizations.removeValue(forKey: identity)
                continue
            }

            if identity == application {
                authorization.expiresAt = nil
            } else {
                switch timing {
                case .immediately:
                    authorizations.removeValue(forKey: identity)
                    continue
                case .afterThirtySeconds:
                    // Further background app switches must not restart the grace period.
                    if authorization.expiresAt == nil {
                        authorization.expiresAt = date.addingTimeInterval(30)
                    }
                case .whenAppQuits:
                    authorization.expiresAt = nil
                }
            }
            authorizations[identity] = authorization
        }
    }

    mutating func didTerminate(processIdentifier: Int32) {
        authorizations = authorizations.filter { $0.key.processIdentifier != processIdentifier }
    }

    mutating func removeAll() {
        authorizations.removeAll()
    }
}
