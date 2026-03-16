import Foundation

struct AppUsageCompletionEvent: Codable, Equatable {
    var taskID: UUID
    var occurredAt: Date
}
