import Foundation

final class DailyRecordStore {
    private let defaults: KeyValueStoring
    private let storageKey = "daily_records_v1"

    init(defaults: KeyValueStoring = SharedDefaultsStore()) {
        self.defaults = defaults
    }

    func loadAll() -> [DailyRecord] {
        CodableStore.load(key: storageKey, defaults: defaults) ?? []
    }

    func saveAll(_ records: [DailyRecord]) {
        CodableStore.save(value: records, key: storageKey, defaults: defaults)
        WidgetTimelineReloader.reloadAll()
    }

    func add(_ record: DailyRecord) {
        var records = loadAll()
        records.append(record)
        saveAll(records)
    }

    func update(_ record: DailyRecord) {
        var records = loadAll()
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            return
        }
        records[index] = record
        saveAll(records)
    }

    func delete(id: UUID) {
        let records = loadAll().filter { $0.id != id }
        saveAll(records)
    }

    func deleteAll(taskId: UUID) {
        let records = loadAll().filter { $0.taskId != taskId }
        saveAll(records)
    }

    func findByID(_ id: UUID) -> DailyRecord? {
        loadAll().first(where: { $0.id == id })
    }
}
