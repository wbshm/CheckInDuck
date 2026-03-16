import Foundation

enum AppPreferences {
    private static let remindersEnabledKey = "app_preferences_reminders_enabled_v1"
    private static let defaultReminderOffsetMinutesKey = "app_preferences_default_reminder_offset_minutes_v1"

    private static let fallbackRemindersEnabled = true
    private static let fallbackReminderOffsetMinutes = 30
    private static let minimumReminderOffsetMinutes = 1

    static func remindersEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: remindersEnabledKey) != nil else {
            return fallbackRemindersEnabled
        }
        return defaults.bool(forKey: remindersEnabledKey)
    }

    static func setRemindersEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: remindersEnabledKey)
    }

    static func defaultReminderOffsetMinutes(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: defaultReminderOffsetMinutesKey) != nil else {
            return fallbackReminderOffsetMinutes
        }

        let storedValue = defaults.integer(forKey: defaultReminderOffsetMinutesKey)
        return max(storedValue, minimumReminderOffsetMinutes)
    }

    static func setDefaultReminderOffsetMinutes(_ minutes: Int, defaults: UserDefaults = .standard) {
        defaults.set(max(minutes, minimumReminderOffsetMinutes), forKey: defaultReminderOffsetMinutesKey)
    }
}
