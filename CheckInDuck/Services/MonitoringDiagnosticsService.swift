import Foundation
import DeviceActivity

struct MonitoringDiagnostics {
    let appGroupContainerAvailable: Bool
    let monitoredActivityNames: [String]
    let completionSnapshot: AppUsageCompletionEventDebugSnapshot
}

final class MonitoringDiagnosticsService {
    private let center = DeviceActivityCenter()
    private let completionEventStore: AppUsageCompletionEventDebugging

    init(completionEventStore: AppUsageCompletionEventDebugging = AppUsageCompletionEventStore()) {
        self.completionEventStore = completionEventStore
    }

    func snapshot(now: Date = Date()) -> MonitoringDiagnostics {
        MonitoringDiagnostics(
            appGroupContainerAvailable: AppGroupConfiguration.isContainerAvailable(),
            monitoredActivityNames: center.activities.map(\.rawValue).sorted(),
            completionSnapshot: completionEventStore.debugSnapshot(now: now)
        )
    }
}
