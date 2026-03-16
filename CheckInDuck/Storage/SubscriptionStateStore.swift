import Foundation

@MainActor
final class SubscriptionStateStore {
    private let defaults: KeyValueStoring
    private let storageKey = "subscription_state_v1"

    init(defaults: KeyValueStoring? = nil) {
        self.defaults = defaults ?? UserDefaults.standard
    }

    func load() -> SubscriptionState {
        CodableStore.load(key: storageKey, defaults: defaults) ?? .default
    }

    func save(_ state: SubscriptionState) {
        CodableStore.save(value: state, key: storageKey, defaults: defaults)
    }
}
