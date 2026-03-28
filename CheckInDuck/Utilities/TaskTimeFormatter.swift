import Foundation

enum TaskTimeFormatter {
    static func timeText(_ date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func thresholdText(seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        return "\(minutes)m"
    }

    static func deadlineBadgeText(_ deadlineText: String) -> String {
        L10n.format("time.deadline_short", deadlineText)
    }

    static func thresholdBadgeText(seconds: Int) -> String {
        L10n.format("time.threshold_short", thresholdText(seconds: seconds))
    }

    static func completionSymbol(_ source: CompletionSource?) -> String {
        switch source {
        case .manual:
            return "hand.tap.fill"
        case .appUsageThreshold:
            return "app.badge.checkmark"
        case nil:
            return "clock.badge.checkmark"
        }
    }

    static func completionBadgeText(source: CompletionSource?, completedAt: Date?) -> String? {
        guard let timeText = timeText(completedAt) else { return nil }
        switch source {
        case .manual:
            return L10n.format("time.completion_manual_short", timeText)
        case .appUsageThreshold:
            return L10n.format("time.completion_auto_short", timeText)
        case nil:
            return L10n.format("time.completion_short", timeText)
        }
    }

    static func completionDetailText(source: CompletionSource?, completedAt: Date?) -> String? {
        let sourceText = completionSourceText(source)
        guard let completedAt else {
            return sourceText
        }

        let timeText = timeText(completedAt) ?? ""
        switch source {
        case .manual:
            return L10n.format("history.source.manual_with_time", timeText)
        case .appUsageThreshold:
            return L10n.format("history.source.app_usage_with_time", timeText)
        case nil:
            return L10n.format("history.source.completed_with_time", timeText)
        }
    }

    static func completionSourceText(_ source: CompletionSource?) -> String? {
        switch source {
        case .manual:
            return L10n.tr("history.source.manual")
        case .appUsageThreshold:
            return L10n.tr("history.source.app_usage")
        case nil:
            return nil
        }
    }
}
