import Foundation

final class SharedDefaultsStore: KeyValueStoring {
    private let primary: KeyValueStoring
    private let legacy: KeyValueStoring

    init(
        primary: KeyValueStoring = AppGroupConfiguration.sharedDefaults(),
        legacy: KeyValueStoring = UserDefaults.standard
    ) {
        self.primary = primary
        self.legacy = legacy
    }

    func data(forKey defaultName: String) -> Data? {
        if let primaryData = primary.data(forKey: defaultName) {
            return primaryData
        }

        guard let legacyData = legacy.data(forKey: defaultName) else {
            return nil
        }

        primary.set(legacyData, forKey: defaultName)
        return legacyData
    }

    func set(_ value: Any?, forKey defaultName: String) {
        primary.set(value, forKey: defaultName)
        legacy.set(value, forKey: defaultName)
    }
}
