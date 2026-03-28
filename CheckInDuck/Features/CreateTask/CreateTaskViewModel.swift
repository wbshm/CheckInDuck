import Foundation
import Combine

@MainActor
final class CreateTaskViewModel: ObservableObject {
    @Published var taskName = ""
    @Published var deadlineHour = 21
    @Published var deadlineMinute = 0
    @Published var recurrence: TaskRecurrence = .daily
    @Published var usageThresholdMinutes = 3
    @Published var selectedAppSelectionData: Data?
    @Published private(set) var editingTask: HabitTask?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEditing: Bool {
        editingTask != nil
    }

    var saveButtonDisabled: Bool {
        taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedAppSelectionData == nil
    }

    func resetDraft() {
        editingTask = nil
        taskName = ""
        deadlineHour = 21
        deadlineMinute = 0
        recurrence = .daily
        usageThresholdMinutes = 3
        selectedAppSelectionData = nil
    }

    func loadDraft(from task: HabitTask) {
        editingTask = task
        taskName = task.name
        deadlineHour = task.deadline.hour
        deadlineMinute = task.deadline.minute
        recurrence = task.recurrence
        usageThresholdMinutes = max(task.usageThresholdSeconds / 60, 1)
        selectedAppSelectionData = task.appSelectionData
    }

    func buildTask() -> HabitTask? {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let selectedAppSelectionData else {
            return nil
        }

        let deadline = DailyDeadline(hour: deadlineHour, minute: deadlineMinute)
        let usageThresholdSeconds = max(usageThresholdMinutes, 1) * 60

        if let editingTask {
            return HabitTask(
                id: editingTask.id,
                name: trimmedName,
                appSelectionData: selectedAppSelectionData,
                deadline: deadline,
                recurrence: recurrence,
                usageThresholdSeconds: usageThresholdSeconds,
                isEnabled: editingTask.isEnabled,
                reminderConfig: editingTask.reminderConfig,
                createdAt: editingTask.createdAt,
                updatedAt: Date()
            )
        }

        return HabitTask(
            name: trimmedName,
            appSelectionData: selectedAppSelectionData,
            deadline: deadline,
            recurrence: recurrence,
            usageThresholdSeconds: usageThresholdSeconds,
            reminderConfig: ReminderConfig(
                isEnabled: AppPreferences.remindersEnabled(defaults: defaults),
                offsetsInMinutes: [AppPreferences.defaultReminderOffsetMinutes(defaults: defaults)]
            )
        )
    }
}
