import Foundation
import Combine

enum TodayTaskFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case completed
    case missed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.tr("today.filter.all")
        case .pending:
            return L10n.tr("status.pending")
        case .completed:
            return L10n.tr("status.completed")
        case .missed:
            return L10n.tr("status.missed")
        }
    }

    var status: DailyTaskStatus? {
        switch self {
        case .all:
            return nil
        case .pending:
            return .pending
        case .completed:
            return .completed
        case .missed:
            return .missed
        }
    }
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var tasks: [HabitTask] = []
    @Published private(set) var records: [DailyRecord] = []
    @Published var selectedFilter: TodayTaskFilter = .all

    private let taskStore: TaskStore
    private let dailyRecordStore: DailyRecordStore
    private let calendar: Calendar
    private let statusCalculator: DailyStatusCalculator
    private let reminderScheduling: ReminderScheduling
    private let appUsageMonitoring: AppUsageMonitoring
    private let appUsageCompletionEvents: AppUsageCompletionEventReading
    private let nowProvider: () -> Date
    private var monitoringFingerprintByTaskID: [UUID: String] = [:]

    convenience init() {
        self.init(
            taskStore: TaskStore(),
            dailyRecordStore: DailyRecordStore(),
            calendar: .current,
            reminderScheduling: ReminderSchedulingService(),
            appUsageMonitoring: AppUsageMonitoringService(),
            appUsageCompletionEvents: AppUsageCompletionEventStore()
        )
    }

    init(
        taskStore: TaskStore,
        dailyRecordStore: DailyRecordStore,
        calendar: Calendar,
        reminderScheduling: ReminderScheduling,
        appUsageMonitoring: AppUsageMonitoring,
        appUsageCompletionEvents: AppUsageCompletionEventReading,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskStore = taskStore
        self.dailyRecordStore = dailyRecordStore
        self.calendar = calendar
        self.statusCalculator = DailyStatusCalculator(calendar: calendar)
        self.reminderScheduling = reminderScheduling
        self.appUsageMonitoring = appUsageMonitoring
        self.appUsageCompletionEvents = appUsageCompletionEvents
        self.nowProvider = nowProvider
        reload()
        scheduleRemindersForEnabledTasks()
        startMonitoringForEnabledTasks()
    }

    func reload() {
        tasks = taskStore.loadAll().sorted { $0.createdAt < $1.createdAt }
        pruneOrphanRecordsIfNeeded(validTaskIDs: Set(tasks.map(\.id)))
        records = dailyRecordStore.loadAll()
    }

    func addTask(_ task: HabitTask) {
        taskStore.add(task)
        reload()
        scheduleRemindersIfNeeded(for: task)
        startMonitoringIfNeeded(for: task)
    }

    func updateTask(_ task: HabitTask) {
        taskStore.update(task)
        reload()
        cancelReminders(for: task.id)
        stopMonitoring(taskID: task.id)
        monitoringFingerprintByTaskID.removeValue(forKey: task.id)

        if task.isEnabled {
            scheduleRemindersIfNeeded(for: task)
            startMonitoringIfNeeded(for: task)
        }
    }

    func deleteTask(id: UUID) {
        taskStore.delete(id: id)
        dailyRecordStore.deleteAll(taskId: id)
        reload()
        cancelReminders(for: id)
        stopMonitoring(taskID: id)
        monitoringFingerprintByTaskID.removeValue(forKey: id)
    }

    func toggleEnabled(task: HabitTask) {
        setEnabled(task: task, isEnabled: !task.isEnabled)
    }

    func setEnabled(task: HabitTask, isEnabled: Bool) {
        guard task.isEnabled != isEnabled else { return }

        var updated = task
        updated.isEnabled = isEnabled
        updated.updatedAt = Date()
        taskStore.update(updated)
        reload()
        if updated.isEnabled {
            scheduleRemindersIfNeeded(for: updated)
            startMonitoringIfNeeded(for: updated)
        } else {
            cancelReminders(for: updated.id)
            stopMonitoring(taskID: updated.id)
            monitoringFingerprintByTaskID.removeValue(forKey: updated.id)
        }
    }

    func markCompleted(taskID: UUID, source: CompletionSource) {
        let now = nowProvider()
        let today = calendar.startOfDay(for: now)
        if var existing = todayRecord(for: taskID, on: now) {
            existing.status = .completed
            existing.completionSource = source
            existing.completedAt = now
            dailyRecordStore.update(existing)
        } else {
            let record = DailyRecord(
                taskId: taskID,
                date: today,
                status: .completed,
                completionSource: source,
                completedAt: now
            )
            dailyRecordStore.add(record)
        }
        reload()
    }

    func evaluateDailyStatuses(now: Date = Date()) {
        syncAppUsageCompletions()

        let allRecords = dailyRecordStore.loadAll()
        let missingRecords = statusCalculator.missingRecordsToInsert(
            for: tasks,
            existingRecords: allRecords,
            now: now
        )

        if !missingRecords.isEmpty {
            dailyRecordStore.saveAll(allRecords + missingRecords)
        }
        reload()
    }

    func refreshForForeground() {
        reload()
        scheduleRemindersForEnabledTasks()
        evaluateDailyStatuses()
    }

    func status(for task: HabitTask) -> DailyTaskStatus {
        statusCalculator.status(for: task, records: records, now: nowProvider())
    }

    func visibleStatus(for task: HabitTask) -> DailyTaskStatus? {
        if let todayRecord = todayRecord(for: task.id, on: nowProvider()) {
            return todayRecord.status
        }
        guard task.isEnabled else {
            return nil
        }
        guard task.occurs(on: nowProvider(), calendar: calendar) else {
            return nil
        }
        return status(for: task)
    }

    func deadlineText(for task: HabitTask) -> String {
        task.deadline.displayText
    }

    func completionDetailText(for task: HabitTask) -> String? {
        guard let todayRecord = todayRecord(for: task.id, on: nowProvider()) else {
            return nil
        }
        return completionDetailText(
            source: todayRecord.completionSource,
            completedAt: todayRecord.completedAt
        )
    }

    var completedCount: Int {
        scheduledTasks.filter { visibleStatus(for: $0) == .completed }.count
    }

    var missedCount: Int {
        scheduledTasks.filter { visibleStatus(for: $0) == .missed }.count
    }

    var pendingCount: Int {
        scheduledTasks.filter { visibleStatus(for: $0) == .pending }.count
    }

    var scheduledTasks: [HabitTask] {
        tasks.filter { $0.occurs(on: nowProvider(), calendar: calendar) }
    }

    var displayedTasks: [HabitTask] {
        orderedTasks(scheduledTasks).filter { task in
            guard let selectedStatus = selectedFilter.status else { return true }
            return visibleStatus(for: task) == selectedStatus
        }
    }

    private func todayRecord(for taskID: UUID, on date: Date = Date()) -> DailyRecord? {
        records.first(where: { $0.taskId == taskID && calendar.isDate($0.date, inSameDayAs: date) })
    }

    private func orderedTasks(_ tasks: [HabitTask]) -> [HabitTask] {
        tasks.sorted { lhs, rhs in
            let lhsStatus = visibleStatus(for: lhs)
            let rhsStatus = visibleStatus(for: rhs)

            let lhsPriority = sortPriority(for: lhsStatus)
            let rhsPriority = sortPriority(for: rhsStatus)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            if lhs.deadline.hour != rhs.deadline.hour {
                return lhs.deadline.hour < rhs.deadline.hour
            }

            if lhs.deadline.minute != rhs.deadline.minute {
                return lhs.deadline.minute < rhs.deadline.minute
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private func sortPriority(for status: DailyTaskStatus?) -> Int {
        switch status {
        case nil:
            return 3
        case .missed:
            return 0
        case .pending:
            return 1
        case .completed:
            return 2
        }
    }

    private func completionDetailText(source: CompletionSource?, completedAt: Date?) -> String? {
        guard let completedAt else { return nil }
        let timeText = completedAt.formatted(date: .omitted, time: .shortened)

        switch source {
        case .manual:
            return L10n.format("history.source_with_time", L10n.tr("history.source.manual"), timeText)
        case .appUsageThreshold:
            return L10n.format("history.source_with_time", L10n.tr("history.source.app_usage"), timeText)
        case nil:
            return timeText
        }
    }

    private func scheduleRemindersIfNeeded(for task: HabitTask) {
        guard task.isEnabled else { return }
        Task {
            await reminderScheduling.scheduleReminders(for: task)
        }
    }

    private func scheduleRemindersForEnabledTasks() {
        for task in tasks where task.isEnabled {
            scheduleRemindersIfNeeded(for: task)
        }
    }

    private func cancelReminders(for taskID: UUID) {
        Task {
            await reminderScheduling.cancelReminders(for: taskID)
        }
    }

    private func startMonitoringForEnabledTasks() {
        for task in tasks where task.isEnabled {
            startMonitoringIfNeeded(for: task)
        }
    }

    private func startMonitoringIfNeeded(for task: HabitTask) {
        guard task.isEnabled else { return }
        guard task.appSelectionData != nil else { return }
        let fingerprint = monitoringFingerprint(for: task)
        if monitoringFingerprintByTaskID[task.id] == fingerprint {
            return
        }
        monitoringFingerprintByTaskID[task.id] = fingerprint
        Task {
            await appUsageMonitoring.startMonitoring(task: task)
        }
    }

    private func stopMonitoring(taskID: UUID) {
        monitoringFingerprintByTaskID.removeValue(forKey: taskID)
        Task {
            await appUsageMonitoring.stopMonitoring(taskID: taskID)
        }
    }

    private func syncAppUsageCompletions() {
        let completedTaskIDs = appUsageCompletionEvents.consumeCompletedTaskIDs()
        if !completedTaskIDs.isEmpty {
            print("TodayViewModel: consuming app-usage completion events count=\(completedTaskIDs.count)")
        }
        let validTaskIDs = Set(tasks.map(\.id))
        for taskID in completedTaskIDs {
            guard validTaskIDs.contains(taskID) else {
                print("TodayViewModel: ignore completion event for unknown task \(taskID.uuidString)")
                Task {
                    await appUsageMonitoring.stopMonitoring(taskID: taskID)
                }
                continue
            }
            guard let task = tasks.first(where: { $0.id == taskID }) else {
                continue
            }
            guard task.occurs(on: nowProvider(), calendar: calendar) else {
                print("TodayViewModel: ignore completion event for inactive recurring task \(taskID.uuidString)")
                continue
            }
            markCompleted(taskID: taskID, source: .appUsageThreshold)
        }
    }

    private func pruneOrphanRecordsIfNeeded(validTaskIDs: Set<UUID>) {
        let existingRecords = dailyRecordStore.loadAll()
        let filteredRecords = existingRecords.filter { validTaskIDs.contains($0.taskId) }
        guard filteredRecords.count != existingRecords.count else { return }

        let orphanTaskIDs = Set(existingRecords.map(\.taskId)).subtracting(validTaskIDs)
        dailyRecordStore.saveAll(filteredRecords)
        for taskID in orphanTaskIDs {
            Task {
                await appUsageMonitoring.stopMonitoring(taskID: taskID)
            }
        }
        print("TodayViewModel: pruned orphan records count=\(existingRecords.count - filteredRecords.count)")
    }

    private func monitoringFingerprint(for task: HabitTask) -> String {
        let selectionHash = task.appSelectionData?.base64EncodedString() ?? "none"
        return "\(task.id.uuidString)|\(task.isEnabled)|\(task.usageThresholdSeconds)|\(task.recurrence.rawValue)|\(selectionHash)"
    }
}
