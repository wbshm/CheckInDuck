import Foundation

struct ReminderConfig: Codable, Equatable {
    var isEnabled: Bool
    var offsetsInMinutes: [Int]

    init(isEnabled: Bool, offsetsInMinutes: [Int]) {
        self.isEnabled = isEnabled
        self.offsetsInMinutes = Array(Set(offsetsInMinutes.filter { $0 > 0 })).sorted(by: >)
    }

    static let `default` = ReminderConfig(
        isEnabled: true,
        offsetsInMinutes: [30, 10]
    )
}
