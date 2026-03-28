import Foundation

final class CalendarDayNoteStore {
    private let defaults: KeyValueStoring
    private let storageKey = "calendar_day_notes_v1"

    init(defaults: KeyValueStoring = SharedDefaultsStore()) {
        self.defaults = defaults
    }

    func loadAll() -> [CalendarDayNote] {
        CodableStore.load(key: storageKey, defaults: defaults) ?? []
    }

    func saveAll(_ notes: [CalendarDayNote]) {
        CodableStore.save(value: notes, key: storageKey, defaults: defaults)
        WidgetTimelineReloader.reloadAll()
    }

    func upsert(text: String, for date: Date, calendar: Calendar) {
        let dayStart = calendar.startOfDay(for: date)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes = loadAll()

        if let index = notes.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            if trimmed.isEmpty {
                notes.remove(at: index)
            } else {
                notes[index].text = trimmed
                notes[index].updatedAt = Date()
                notes[index].date = dayStart
            }
        } else if !trimmed.isEmpty {
            notes.append(CalendarDayNote(date: dayStart, text: trimmed))
        }

        saveAll(notes)
    }
}
