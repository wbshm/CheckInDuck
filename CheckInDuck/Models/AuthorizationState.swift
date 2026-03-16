import Foundation

enum NotificationPermissionStatus: String, Codable {
    case notDetermined
    case denied
    case authorized
}

enum FamilyControlsAuthorizationStatus: String, Codable {
    case notDetermined
    case denied
    case approved
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
