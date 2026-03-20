import Foundation
import FamilyControls
import UserNotifications

protocol AuthorizationServicing {
    func currentState() async -> AuthorizationState
    func requestNotificationPermission() async -> NotificationPermissionStatus
    func requestFamilyControlsAuthorization() async -> FamilyControlsAuthorizationRequestResult
}

protocol NotificationPermissionProviding {
    func currentStatus() async -> NotificationPermissionStatus
    func requestPermission() async -> NotificationPermissionStatus
}

protocol FamilyControlsAuthorizationProviding {
    func currentStatus() -> FamilyControlsAuthorizationStatus
    func requestAuthorization() async -> FamilyControlsAuthorizationRequestResult
}

final class AuthorizationService: AuthorizationServicing {
    private let notificationProvider: NotificationPermissionProviding
    private let familyControlsProvider: FamilyControlsAuthorizationProviding
    private let stateStore: AuthorizationStateStore

    init(
        notificationProvider: NotificationPermissionProviding = SystemNotificationPermissionProvider(),
        familyControlsProvider: FamilyControlsAuthorizationProviding = SystemFamilyControlsAuthorizationProvider(),
        stateStore: AuthorizationStateStore = AuthorizationStateStore()
    ) {
        self.notificationProvider = notificationProvider
        self.familyControlsProvider = familyControlsProvider
        self.stateStore = stateStore
    }

    func currentState() async -> AuthorizationState {
        let state = AuthorizationState(
            notificationPermission: await notificationProvider.currentStatus(),
            familyControlsAuthorization: familyControlsProvider.currentStatus()
        )
        stateStore.save(state)
        return state
    }

    func requestNotificationPermission() async -> NotificationPermissionStatus {
        let status = await notificationProvider.requestPermission()
        var state = stateStore.load() ?? .initial
        state.notificationPermission = status
        stateStore.save(state)
        return status
    }

    func requestFamilyControlsAuthorization() async -> FamilyControlsAuthorizationRequestResult {
        let result = await familyControlsProvider.requestAuthorization()
        var state = stateStore.load() ?? .initial
        state.familyControlsAuthorization = result.status
        stateStore.save(state)
        return result
    }
}

struct SystemNotificationPermissionProvider: NotificationPermissionProviding {
    func currentStatus() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestPermission() async -> NotificationPermissionStatus {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        let granted = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: options) { approved, _ in
                continuation.resume(returning: approved)
            }
        }
        return granted ? .authorized : .denied
    }
}

struct SystemFamilyControlsAuthorizationProvider: FamilyControlsAuthorizationProviding {
    func currentStatus() -> FamilyControlsAuthorizationStatus {
        map(AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async -> FamilyControlsAuthorizationRequestResult {
#if targetEnvironment(simulator)
        return FamilyControlsAuthorizationRequestResult(
            status: currentStatus(),
            errorMessage: "Family Controls authorization is unavailable on Simulator. Please test this on a real device."
        )
#else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return FamilyControlsAuthorizationRequestResult(
                status: currentStatus(),
                errorMessage: nil
            )
        } catch {
            return FamilyControlsAuthorizationRequestResult(
                status: currentStatus(),
                errorMessage: Self.errorMessage(from: error)
            )
        }
#endif
    }

    private static func errorMessage(from error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("helper application") ||
            raw.localizedCaseInsensitiveContains("FamilyControlsAgent") {
            return "Could not connect to FamilyControlsAgent. Confirm Family Controls capability/entitlement is enabled, then retry on a real device."
        }
        return "Family Controls authorization failed: \(raw)"
    }

    private func map(_ status: AuthorizationStatus) -> FamilyControlsAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .approved:
            return .approved
        @unknown default:
            return .notDetermined
        }
    }
}
