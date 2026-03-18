import Foundation

enum NotificationPermissionStatus: String, Codable {
    case notDetermined
    case denied
    case authorized

    var localizedTitle: String {
        switch self {
        case .notDetermined:
            return L10n.tr("authorization.notification.not_determined")
        case .denied:
            return L10n.tr("authorization.notification.denied")
        case .authorized:
            return L10n.tr("authorization.notification.authorized")
        }
    }
}

enum FamilyControlsAuthorizationStatus: String, Codable {
    case notDetermined
    case denied
    case approved

    var localizedTitle: String {
        switch self {
        case .notDetermined:
            return L10n.tr("authorization.family.not_determined")
        case .denied:
            return L10n.tr("authorization.family.denied")
        case .approved:
            return L10n.tr("authorization.family.approved")
        }
    }
}

struct FamilyControlsAuthorizationRequestResult: Equatable {
    var status: FamilyControlsAuthorizationStatus
    var errorMessage: String?
}

struct AuthorizationState: Codable, Equatable {
    var notificationPermission: NotificationPermissionStatus
    var familyControlsAuthorization: FamilyControlsAuthorizationStatus

    static let initial = AuthorizationState(
        notificationPermission: .notDetermined,
        familyControlsAuthorization: .notDetermined
    )
}
