import Foundation
import Combine

@MainActor
final class CreateTaskViewModel: ObservableObject {
    @Published var taskName = ""
    @Published var deadlineHour = 21
    @Published var deadlineMinute = 0
    @Published var usageThresholdMinutes = 3
    @Published var selectedAppSelectionData: Data?
    
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var saveButtonDisabled: Bool {
        taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedAppSelectionData == nil
    }

    func resetDraft() {
        taskName = ""
        deadlineHour = 21
        deadlineMinute = 0
        usageThresholdMinutes = 3
        selectedAppSelectionData = nil
    }

    func buildTask() -> HabitTask? {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let selectedAppSelectionData else {
            return nil
        }
        return HabitTask(
            name: trimmedName,
            appSelectionData: selectedAppSelectionData,
            deadline: DailyDeadline(hour: deadlineHour, minute: deadlineMinute),
            usageThresholdSeconds: max(usageThresholdMinutes, 1) * 60,
            reminderConfig: ReminderConfig(
                isEnabled: AppPreferences.remindersEnabled(defaults: defaults),
                offsetsInMinutes: [AppPreferences.defaultReminderOffsetMinutes(defaults: defaults)]
            )
        )
    }
}
