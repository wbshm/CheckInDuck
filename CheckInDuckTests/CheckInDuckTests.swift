//
//  CheckInDuckTests.swift
//  CheckInDuckTests
//

import Foundation
import Testing
import FamilyControls
@testable import CheckInDuck

struct CheckInDuckTests {
    @Test
    func placeholder() async throws {
        #expect(Bool(true))
    }

    @MainActor
    @Test
    func refreshDoesNotRestartMonitoringForUnchangedTask() async throws {
        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let monitoring = MockAppUsageMonitoring()
        let reminder = NoopReminderScheduling()
        let completionEvents = StubAppUsageCompletionEvents()

        let task = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 23, minute: 0),
            usageThresholdSeconds: 60,
            isEnabled: true
        )
        taskStore.add(task)

        let viewModel = TodayViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: .current,
            reminderScheduling: reminder,
            appUsageMonitoring: monitoring,
            appUsageCompletionEvents: completionEvents
        )

        let started = await waitUntil {
            await monitoring.startCount(for: task.id) == 1
        }
        #expect(started)

        viewModel.refreshForForeground()
        viewModel.evaluateDailyStatuses()
        viewModel.refreshForForeground()

        try? await Task.sleep(nanoseconds: 300_000_000)
        let finalCount = await monitoring.startCount(for: task.id)
        #expect(finalCount == 1)
    }

    @MainActor
    @Test
    func thresholdEventIncludesPastActivityOnSupportedIOS() async throws {
        let event = AppUsageMonitoringService.makeThresholdEvent(
            selection: FamilyActivitySelection(),
            thresholdSeconds: 60
        )

        if #available(iOS 17.4, *) {
            #expect(event.includesPastActivity)
        }
    }

    @MainActor
    @Test
    func thresholdEventUsesMinuteGranularity() async throws {
        let event = AppUsageMonitoringService.makeThresholdEvent(
            selection: FamilyActivitySelection(),
            thresholdSeconds: 60
        )

        #expect(event.threshold.minute == 1)
        #expect((event.threshold.second ?? 0) == 0)
    }

    @MainActor
    @Test
    func createTaskViewModelResetDraftClearsUserInput() async throws {
        let viewModel = CreateTaskViewModel()
        viewModel.taskName = "Read WeChat"
        viewModel.deadlineHour = 8
        viewModel.deadlineMinute = 45
        viewModel.usageThresholdMinutes = 10
        viewModel.selectedAppSelectionData = Data([0x01, 0x02])

        viewModel.resetDraft()

        #expect(viewModel.taskName.isEmpty)
        #expect(viewModel.deadlineHour == 21)
        #expect(viewModel.deadlineMinute == 0)
        #expect(viewModel.usageThresholdMinutes == 3)
        #expect(viewModel.selectedAppSelectionData == nil)
    }

    @MainActor
    @Test
    func parseTaskIDSupportsBootstrapActivityName() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let taskID = UUID(uuidString: "C8ACCC3C-14EF-4F52-8BFC-8024877435E8")!
        let date = Date(timeIntervalSince1970: 1_710_000_000)

        let activity = AppUsageMonitoringService.bootstrapActivityName(
            for: taskID,
            date: date,
            calendar: calendar
        )
        let parsed = AppUsageMonitoringService.parseTaskID(from: activity)

        #expect(parsed == taskID)
    }

    @MainActor
    @Test
    func evaluateDailyStatusesIgnoresCompletionEventsForUnknownTasks() async throws {
        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let monitoring = MockAppUsageMonitoring()
        let reminder = NoopReminderScheduling()
        let knownTask = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 23, minute: 0),
            usageThresholdSeconds: 60,
            isEnabled: true
        )
        taskStore.add(knownTask)

        let unknownTaskID = UUID()
        let completionEvents = StubAppUsageCompletionEvents(completedTaskIDs: [unknownTaskID])
        let viewModel = TodayViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: .current,
            reminderScheduling: reminder,
            appUsageMonitoring: monitoring,
            appUsageCompletionEvents: completionEvents
        )

        viewModel.evaluateDailyStatuses()
        let storedRecords = recordStore.loadAll()
        #expect(storedRecords.contains(where: { $0.taskId == unknownTaskID }) == false)
    }

    @MainActor
    @Test
    func initPrunesOrphanDailyRecords() async throws {
        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let monitoring = MockAppUsageMonitoring()
        let reminder = NoopReminderScheduling()
        let completionEvents = StubAppUsageCompletionEvents()

        let knownTask = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 23, minute: 0),
            usageThresholdSeconds: 60,
            isEnabled: true
        )
        taskStore.add(knownTask)

        let orphanTaskID = UUID()
        recordStore.add(
            DailyRecord(
                taskId: orphanTaskID,
                date: Date(),
                status: .completed,
                completionSource: .appUsageThreshold
            )
        )

        _ = TodayViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: .current,
            reminderScheduling: reminder,
            appUsageMonitoring: monitoring,
            appUsageCompletionEvents: completionEvents
        )

        let storedRecords = recordStore.loadAll()
        #expect(storedRecords.contains(where: { $0.taskId == orphanTaskID }) == false)
    }
}

private final class InMemoryKeyValueStore: KeyValueStoring {
    private var storage: [String: Data] = [:]

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value as? Data
    }
}

private final class MockAppUsageMonitoring: AppUsageMonitoring {
    private actor State {
        var startedTaskIDs: [UUID] = []

        func recordStart(_ taskID: UUID) {
            startedTaskIDs.append(taskID)
        }

        func startCount(for taskID: UUID) -> Int {
            startedTaskIDs.filter { $0 == taskID }.count
        }
    }

    private let state = State()

    func startMonitoring(task: HabitTask) async {
        await state.recordStart(task.id)
    }

    func stopMonitoring(taskID: UUID) async {}

    func startCount(for taskID: UUID) async -> Int {
        await state.startCount(for: taskID)
    }
}

private struct NoopReminderScheduling: ReminderScheduling {
    func scheduleReminders(for task: HabitTask) async {}
    func cancelReminders(for taskID: UUID) async {}
}

private struct StubAppUsageCompletionEvents: AppUsageCompletionEventReading {
    private let completedTaskIDs: [UUID]

    init(completedTaskIDs: [UUID] = []) {
        self.completedTaskIDs = completedTaskIDs
    }

    func consumeCompletedTaskIDs() -> [UUID] { completedTaskIDs }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () async -> Bool
) async -> Bool {
    let start = DispatchTime.now().uptimeNanoseconds
    while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return false
}
