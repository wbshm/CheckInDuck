import Foundation
import Combine

@MainActor
protocol SubscriptionAccessProviding {
    var currentTier: SubscriptionTier { get }
    func isFeatureEnabled(_ feature: AppFeature) -> Bool
    func canCreateTask(currentTaskCount: Int) -> Bool
    func canViewFullHistory() -> Bool
    func historyLookbackDays() -> Int?
    func updateTier(_ tier: SubscriptionTier)
}

@MainActor
final class SubscriptionAccessService: ObservableObject, SubscriptionAccessProviding {
    nonisolated static let freeTaskLimit = 1
    nonisolated static let freeHistoryLookbackDays = 7

    @Published private(set) var state: SubscriptionState

    private let stateStore: SubscriptionStateStore

    convenience init() {
        self.init(stateStore: SubscriptionStateStore())
    }

    init(stateStore: SubscriptionStateStore) {
        self.stateStore = stateStore
        self.state = stateStore.load()
    }

    var currentTier: SubscriptionTier {
        state.tier
    }

    func isFeatureEnabled(_ feature: AppFeature) -> Bool {
        switch feature {
        case .unlimitedTasks, .advancedHistoryFilters, .customReminderWindows:
            return currentTier == .premium
        }
    }

    func canCreateTask(currentTaskCount: Int) -> Bool {
        switch currentTier {
        case .free:
            return currentTaskCount < Self.freeTaskLimit
        case .premium:
            return true
        }
    }

    func canViewFullHistory() -> Bool {
        currentTier == .premium
    }

    func historyLookbackDays() -> Int? {
        canViewFullHistory() ? nil : Self.freeHistoryLookbackDays
    }

    func updateTier(_ tier: SubscriptionTier) {
        state = SubscriptionState(tier: tier, updatedAt: Date())
        stateStore.save(state)
    }
}
