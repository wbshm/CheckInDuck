import Foundation

struct UpgradeEntryCopy {
    let title: String
    let message: String
}

enum UpgradeEntryPoint {
    case settings
    case taskLimit
    case historyLimit
    case reminderCustomization

    var copy: UpgradeEntryCopy {
        switch self {
        case .settings:
            return UpgradeEntryCopy(
                title: "Upgrade to Premium",
                message: "Unlock all premium features for daily habit tracking."
            )
        case .taskLimit:
            return UpgradeEntryCopy(
                title: "Task Limit Reached",
                message: "Free tier supports up to \(SubscriptionAccessService.freeTaskLimit) task(s). Upgrade for unlimited tasks."
            )
        case .historyLimit:
            return UpgradeEntryCopy(
                title: "History Is Limited",
                message: "Free tier shows only the latest \(SubscriptionAccessService.freeHistoryLookbackDays) days. Upgrade to view full history."
            )
        case .reminderCustomization:
            return UpgradeEntryCopy(
                title: "Custom Reminders Need Premium",
                message: "Upgrade to choose your own reminder lead time."
            )
        }
    }
}

enum UpgradePlanSelector {
    static func preferredProductID(from productIDs: [String]) -> String? {
        if productIDs.contains(SubscriptionProductCatalog.yearly) {
            return SubscriptionProductCatalog.yearly
        }
        if productIDs.contains(SubscriptionProductCatalog.monthly) {
            return SubscriptionProductCatalog.monthly
        }
        return productIDs.first
    }
}
