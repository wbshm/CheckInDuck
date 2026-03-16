import Foundation

final class TaskStore {
    private let defaults: KeyValueStoring
    private let storageKey = "habit_tasks_v1"

    init(defaults: KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
    }

    func loadAll() -> [HabitTask] {
        CodableStore.load(key: storageKey, defaults: defaults) ?? []
    }

    func saveAll(_ tasks: [HabitTask]) {
        CodableStore.save(value: tasks, key: storageKey, defaults: defaults)
    }

    func add(_ task: HabitTask) {
        var tasks = loadAll()
        tasks.append(task)
        saveAll(tasks)
    }

    func update(_ task: HabitTask) {
        var tasks = loadAll()
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        tasks[index] = task
        saveAll(tasks)
    }

    func delete(id: UUID) {
        let tasks = loadAll().filter { $0.id != id }
        saveAll(tasks)
    }

    func findByID(_ id: UUID) -> HabitTask? {
        loadAll().first(where: { $0.id == id })
    }
}
