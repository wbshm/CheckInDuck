import Foundation

struct CalendarDayNote: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var text: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        text: String,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.updatedAt = updatedAt
    }
}
