import Foundation

final class AuthorizationStateStore {
    private let defaults: KeyValueStoring
    private let storageKey = "authorization_state_v1"

    init(defaults: KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
    }

    func load() -> AuthorizationState? {
        CodableStore.load(key: storageKey, defaults: defaults)
    }

    func save(_ state: AuthorizationState) {
        CodableStore.save(value: state, key: storageKey, defaults: defaults)
    }
}
