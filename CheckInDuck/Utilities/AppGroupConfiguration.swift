import Foundation

enum AppGroupConfiguration {
    static let suiteName = "group.com.wang.CheckInDuck"

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func isContainerAvailable() -> Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil
    }
}
