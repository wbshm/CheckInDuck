import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium

    var localizedTitle: String {
        switch self {
        case .free:
            return L10n.tr("subscription.tier.free")
        case .premium:
            return L10n.tr("subscription.tier.premium")
        }
    }
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
