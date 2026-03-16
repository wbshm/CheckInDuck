import Foundation

struct DailyDeadline: Codable, Equatable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
