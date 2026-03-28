import Foundation
import Testing
@testable import CheckInDuck

@MainActor
struct WidgetSupportTests {
    @Test
    func sharedDefaultsStoreReadsLegacyDataAndMigratesToPrimary() async throws {
        let primary = InMemoryKeyValueStore()
        let legacy = InMemoryKeyValueStore()
        let expected = Data([0x10, 0x20, 0x30])
        legacy.set(expected, forKey: "habit_tasks_v1")

        let store = SharedDefaultsStore(primary: primary, legacy: legacy)

        let loaded = store.data(forKey: "habit_tasks_v1")

        #expect(loaded == expected)
        #expect(primary.data(forKey: "habit_tasks_v1") == expected)
    }

    @Test
    func widgetTaskStatusSnapshotBuilderBuildsTodaySummaryAndPrioritizesVisibleTasks() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-03-18T15:00:00Z")!
        let pendingTask = HabitTask(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Inbox Zero",
            deadline: DailyDeadline(hour: 20, minute: 0),
            isEnabled: true
        )
        let completedTask = HabitTask(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Standup",
            deadline: DailyDeadline(hour: 9, minute: 0),
            isEnabled: true
        )
        let missedTask = HabitTask(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Read",
            deadline: DailyDeadline(hour: 12, minute: 0),
            isEnabled: true
        )
        let disabledTask = HabitTask(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            name: "Hidden",
            deadline: DailyDeadline(hour: 18, minute: 0),
            isEnabled: false
        )
        let records = [
            DailyRecord(taskId: completedTask.id, date: now, status: .completed, completionSource: .manual),
        ]

        let builder = WidgetTaskStatusSnapshotBuilder(calendar: calendar)
        let snapshot = builder.build(
            tasks: [completedTask, pendingTask, missedTask, disabledTask],
            records: records,
            now: now
        )

        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.completedCount == 1)
        #expect(snapshot.missedCount == 1)
        #expect(snapshot.tasks.map(\.title) == ["Inbox Zero", "Read", "Standup"])
        #expect(snapshot.tasks.map(\.status) == [.pending, .missed, .completed])
    }

    @Test
    func widgetTaskStatusSnapshotBuilderExcludesRecurringTasksThatAreNotDueToday() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-03-18T15:00:00Z")!
        let weeklyDueToday = HabitTask(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            name: "Weekly Due",
            deadline: DailyDeadline(hour: 20, minute: 0),
            recurrence: .weekly,
            isEnabled: true,
            createdAt: ISO8601DateFormatter().date(from: "2026-03-11T09:00:00Z")!,
            updatedAt: ISO8601DateFormatter().date(from: "2026-03-11T09:00:00Z")!
        )
        let weeklyNotDueToday = HabitTask(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            name: "Weekly Off",
            deadline: DailyDeadline(hour: 20, minute: 0),
            recurrence: .weekly,
            isEnabled: true,
            createdAt: ISO8601DateFormatter().date(from: "2026-03-12T09:00:00Z")!,
            updatedAt: ISO8601DateFormatter().date(from: "2026-03-12T09:00:00Z")!
        )

        let builder = WidgetTaskStatusSnapshotBuilder(calendar: calendar)
        let snapshot = builder.build(
            tasks: [weeklyDueToday, weeklyNotDueToday],
            records: [],
            now: now
        )

        #expect(snapshot.tasks.map(\.title) == ["Weekly Due"])
        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.completedCount == 0)
        #expect(snapshot.missedCount == 0)
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
