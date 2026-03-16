import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium
}

struct SubscriptionState: Codable, Equatable {
    var tier: SubscriptionTier
    var updatedAt: Date

    static let `default` = SubscriptionState(
        tier: .free,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

enum AppFeature {
    case unlimitedTasks
    case advancedHistoryFilters
    case customReminderWindows
}
