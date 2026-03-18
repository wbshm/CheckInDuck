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
                title: L10n.tr("upgrade.entry.settings.title"),
                message: L10n.tr("upgrade.entry.settings.message")
            )
        case .taskLimit:
            return UpgradeEntryCopy(
                title: L10n.tr("upgrade.entry.task_limit.title"),
                message: L10n.format(
                    "upgrade.entry.task_limit.message",
                    SubscriptionAccessService.freeTaskLimit
                )
            )
        case .historyLimit:
            return UpgradeEntryCopy(
                title: L10n.tr("upgrade.entry.history_limit.title"),
                message: L10n.format(
                    "upgrade.entry.history_limit.message",
                    SubscriptionAccessService.freeHistoryLookbackDays
                )
            )
        case .reminderCustomization:
            return UpgradeEntryCopy(
                title: L10n.tr("upgrade.entry.reminder_customization.title"),
                message: L10n.tr("upgrade.entry.reminder_customization.message")
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
