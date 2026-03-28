//
//  CheckInDuckTests.swift
//  CheckInDuckTests
//

import Foundation
import Testing
import FamilyControls
import UserNotifications
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
    func initSchedulesRemindersForExistingEnabledTasks() async throws {
        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let monitoring = MockAppUsageMonitoring()
        let reminder = TrackingReminderScheduling()
        let completionEvents = StubAppUsageCompletionEvents()

        let enabledTask = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 23, minute: 0),
            usageThresholdSeconds: 60,
            isEnabled: true
        )
        let disabledTask = HabitTask(
            name: "Safari",
            appSelectionData: Data([0x02]),
            deadline: DailyDeadline(hour: 21, minute: 0),
            usageThresholdSeconds: 60,
            isEnabled: false
        )
        taskStore.add(enabledTask)
        taskStore.add(disabledTask)

        _ = TodayViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: .current,
            reminderScheduling: reminder,
            appUsageMonitoring: monitoring,
            appUsageCompletionEvents: completionEvents
        )

        let scheduledEnabled = await waitUntil {
            await reminder.scheduleCount(for: enabledTask.id) == 1
        }

        #expect(scheduledEnabled)
        #expect(await reminder.scheduleCount(for: disabledTask.id) == 0)
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

    @Test
    func onboardingPreferencePersistsCompletion() async throws {
        let defaults = UserDefaults(suiteName: "CheckInDuckTests.onboardingPreferencePersistsCompletion")!
        defaults.removePersistentDomain(forName: "CheckInDuckTests.onboardingPreferencePersistsCompletion")
        defer {
            defaults.removePersistentDomain(forName: "CheckInDuckTests.onboardingPreferencePersistsCompletion")
        }

        #expect(AppPreferences.hasCompletedOnboarding(defaults: defaults) == false)

        AppPreferences.setHasCompletedOnboarding(true, defaults: defaults)

        #expect(AppPreferences.hasCompletedOnboarding(defaults: defaults) == true)
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

    @Test
    func reminderScheduleIncludesDeadlineTrigger() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)

        let service = ReminderSchedulingService(
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let task = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )

        let components = service.reminderScheduleComponents(
            for: task,
            referenceDate: referenceDate
        )
        let offsets = Set(components.map(\.offsetMinutes))

        #expect(offsets.contains(30))
        #expect(offsets.contains(0))
    }

    @Test
    func deadlineReminderUsesTimeSensitiveInterruptionLevel() async throws {
        let service = ReminderSchedulingService()
        let task = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )

        let content = service.makeReminderContent(for: task, offsetMinutes: 0)

        #expect(content.interruptionLevel == UNNotificationInterruptionLevel.timeSensitive)
        #expect(content.relevanceScore == 1.0)
        #expect(content.threadIdentifier == "task-reminders")
    }

    @Test
    func preDeadlineReminderUsesActiveInterruptionLevel() async throws {
        let service = ReminderSchedulingService()
        let task = HabitTask(
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )

        let content = service.makeReminderContent(for: task, offsetMinutes: 30)

        #expect(content.interruptionLevel == UNNotificationInterruptionLevel.active)
        #expect(content.relevanceScore == 0.5)
    }

    @Test
    func reminderScheduleUsesSecondLevelStaggering() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)

        let service = ReminderSchedulingService(
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let task = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )

        let components = service.reminderScheduleComponents(
            for: task,
            referenceDate: referenceDate
        )

        let preDeadlineSecond = components.first(where: { $0.offsetMinutes == 30 })?.triggerDate.second
        let deadlineSecond = components.first(where: { $0.offsetMinutes == 0 })?.triggerDate.second

        #expect(preDeadlineSecond != nil)
        #expect(deadlineSecond != nil)
        #expect((preDeadlineSecond ?? -1) >= 0)
        #expect((preDeadlineSecond ?? 100) < 50)
        #expect(deadlineSecond == 0)
    }

    @Test
    func reminderScheduleSpreadsTasksWithSameMinute() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)

        let service = ReminderSchedulingService(
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let firstTask = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "WeChat",
            appSelectionData: Data([0x01]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )
        let secondTask = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Safari",
            appSelectionData: Data([0x02]),
            deadline: DailyDeadline(hour: 22, minute: 30),
            usageThresholdSeconds: 60,
            isEnabled: true,
            reminderConfig: ReminderConfig(isEnabled: true, offsetsInMinutes: [30])
        )

        let firstSecond = service.reminderScheduleComponents(
            for: firstTask,
            referenceDate: referenceDate
        ).first(where: { $0.offsetMinutes == 30 })?.triggerDate.second

        let secondSecond = service.reminderScheduleComponents(
            for: secondTask,
            referenceDate: referenceDate
        ).first(where: { $0.offsetMinutes == 30 })?.triggerDate.second

        #expect(firstSecond != nil)
        #expect(secondSecond != nil)
        #expect(firstSecond != secondSecond)
    }

    @MainActor
    @Test
    func calendarSummaryForTodayShowsMixedStatusesWithPriority() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let createdAt = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let todayStart = calendar.startOfDay(for: now)

        let completedTask = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            name: "Completed",
            deadline: DailyDeadline(hour: 23, minute: 0),
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let pendingTask = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
            name: "Pending",
            deadline: DailyDeadline(hour: 23, minute: 0),
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let missedTask = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
            name: "Missed",
            deadline: DailyDeadline(hour: 21, minute: 0),
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        taskStore.saveAll([completedTask, pendingTask, missedTask])
        recordStore.saveAll([
            DailyRecord(taskId: completedTask.id, date: todayStart, status: .completed, completionSource: .manual),
            DailyRecord(taskId: missedTask.id, date: todayStart, status: .missed)
        ])

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let summary = viewModel.summary(for: now)
        #expect(summary.completedCount == 1)
        #expect(summary.pendingCount == 1)
        #expect(summary.missedCount == 1)
        #expect(summary.primaryStatus == .missed)
    }

    @MainActor
    @Test
    func calendarSummaryForPastDayMarksMissingRecordAsMissed() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let pastDay = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let createdAt = calendar.date(byAdding: .day, value: -5, to: now) ?? now

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let task = HabitTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
            name: "Workout",
            deadline: DailyDeadline(hour: 20, minute: 0),
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        taskStore.saveAll([task])

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let summary = viewModel.summary(for: pastDay)
        #expect(summary.completedCount == 0)
        #expect(summary.pendingCount == 0)
        #expect(summary.missedCount == 1)
        #expect(summary.primaryStatus == .missed)
    }

    @MainActor
    @Test
    func calendarMonthNavigationIsLockedWhenNoPastOrFutureData() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let anchorBeforeMove = viewModel.monthAnchor
        #expect(viewModel.canMoveToPreviousMonth == false)
        #expect(viewModel.canMoveToNextMonth == false)

        viewModel.moveMonth(by: -1)
        #expect(viewModel.monthAnchor == anchorBeforeMove)
        viewModel.moveMonth(by: 1)
        #expect(viewModel.monthAnchor == anchorBeforeMove)
    }

    @MainActor
    @Test
    func calendarMonthNavigationAllowsPreviousMonthWhenHistoricalDataExists() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let historicalDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        recordStore.saveAll([
            DailyRecord(taskId: UUID(), date: historicalDate, status: .completed)
        ])

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        #expect(viewModel.canMoveToPreviousMonth)
        #expect(viewModel.canMoveToNextMonth == false)
    }

    @MainActor
    @Test
    func calendarSelectDateOnlyWorksForDaysWithData() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let dataDay = calendar.date(byAdding: .day, value: 4, to: monthStart) ?? now
        let emptyDay = calendar.date(byAdding: .day, value: 6, to: monthStart) ?? now

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        recordStore.saveAll([
            DailyRecord(taskId: UUID(), date: dataDay, status: .completed, completionSource: .manual)
        ])

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let initialSelectedDate = viewModel.selectedDate
        #expect(initialSelectedDate == calendar.startOfDay(for: now))

        viewModel.selectDate(emptyDay)
        #expect(viewModel.selectedDate == initialSelectedDate)

        viewModel.selectDate(dataDay)
        #expect(viewModel.selectedDate != nil)
        #expect(viewModel.selectedDayDetail != nil)
        #expect(viewModel.selectedDayDetail?.summary.completedCount == 1)
        #expect(viewModel.selectedDayDetail?.taskDetails.isEmpty == false)
    }

    @MainActor
    @Test
    func calendarDefaultsToSelectingToday() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        #expect(viewModel.selectedDate == calendar.startOfDay(for: now))
    }

    @MainActor
    @Test
    func calendarMonthInsightsAggregatesRecordCounts() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let day1 = calendar.date(byAdding: .day, value: 1, to: monthStart) ?? now
        let day2 = calendar.date(byAdding: .day, value: 2, to: monthStart) ?? now
        let day3 = calendar.date(byAdding: .day, value: 3, to: monthStart) ?? now

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        recordStore.saveAll([
            DailyRecord(taskId: UUID(), date: day1, status: .completed),
            DailyRecord(taskId: UUID(), date: day2, status: .pending),
            DailyRecord(taskId: UUID(), date: day3, status: .missed)
        ])

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let insights = viewModel.monthInsights
        #expect(insights.activeDays == 3)
        #expect(insights.completedCount == 1)
        #expect(insights.pendingCount == 1)
        #expect(insights.missedCount == 1)
        #expect(insights.completionRate != nil)
        #expect(abs((insights.completionRate ?? 0) - (1.0 / 3.0)) < 0.000_1)
    }

    @MainActor
    @Test
    func calendarNoteOnlyDayIsSelectableAndMarked() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let noteDay = calendar.date(byAdding: .day, value: 7, to: monthStart) ?? now

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let noteStore = CalendarDayNoteStore(defaults: defaults)
        noteStore.upsert(text: "Busy day", for: noteDay, calendar: calendar)

        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            dayNoteStore: noteStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        let summary = viewModel.summary(for: noteDay)
        #expect(summary.hasNote)
        #expect(summary.hasData == false)
        #expect(summary.hasContent)

        viewModel.selectDate(noteDay)
        #expect(viewModel.selectedDate == calendar.startOfDay(for: noteDay))
        #expect(viewModel.dayDetail(for: noteDay)?.noteText == "Busy day")
    }

    @MainActor
    @Test
    func calendarUpdateNotePersistsForSelectedDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let now = Date(timeIntervalSince1970: 1_772_000_000)

        let defaults = InMemoryKeyValueStore()
        let taskStore = TaskStore(defaults: defaults)
        let recordStore = DailyRecordStore(defaults: defaults)
        let noteStore = CalendarDayNoteStore(defaults: defaults)
        let viewModel = CalendarViewModel(
            taskStore: taskStore,
            dailyRecordStore: recordStore,
            dayNoteStore: noteStore,
            calendar: calendar,
            subscriptionAccess: StubSubscriptionAccess(currentTier: .premium),
            monthAnchor: now,
            nowProvider: { now }
        )

        viewModel.updateNote("Review this day", for: now)
        #expect(viewModel.noteText(for: now) == "Review this day")
        #expect(viewModel.summary(for: now).hasNote)

        viewModel.updateNote("", for: now)
        #expect(viewModel.noteText(for: now) == nil)
        #expect(viewModel.summary(for: now).hasNote == false)
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

private final class TrackingReminderScheduling: ReminderScheduling {
    private actor State {
        var scheduledTaskIDs: [UUID] = []

        func recordSchedule(_ taskID: UUID) {
            scheduledTaskIDs.append(taskID)
        }

        func scheduleCount(for taskID: UUID) -> Int {
            scheduledTaskIDs.filter { $0 == taskID }.count
        }
    }

    private let state = State()

    func scheduleReminders(for task: HabitTask) async {
        await state.recordSchedule(task.id)
    }

    func cancelReminders(for taskID: UUID) async {}

    func scheduleCount(for taskID: UUID) async -> Int {
        await state.scheduleCount(for: taskID)
    }
}

@MainActor
private final class StubSubscriptionAccess: SubscriptionAccessProviding {
    private(set) var currentTier: SubscriptionTier
    private let lookbackDaysOverride: Int?

    init(
        currentTier: SubscriptionTier = .premium,
        lookbackDaysOverride: Int? = nil
    ) {
        self.currentTier = currentTier
        self.lookbackDaysOverride = lookbackDaysOverride
    }

    func isFeatureEnabled(_ feature: AppFeature) -> Bool {
        currentTier == .premium
    }

    func canCreateTask(currentTaskCount: Int) -> Bool {
        switch currentTier {
        case .free:
            return currentTaskCount < SubscriptionAccessService.freeTaskLimit
        case .premium:
            return true
        }
    }

    func canViewFullHistory() -> Bool {
        historyLookbackDays() == nil
    }

    func historyLookbackDays() -> Int? {
        if let lookbackDaysOverride {
            return lookbackDaysOverride
        }
        return currentTier == .premium ? nil : SubscriptionAccessService.freeHistoryLookbackDays
    }

    func updateTier(_ tier: SubscriptionTier) {
        currentTier = tier
    }
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
