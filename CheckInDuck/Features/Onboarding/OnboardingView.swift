import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase

    private enum Step: Int, CaseIterable {
        case intro
        case notifications
        case familyControls
    }

    let onFinish: () -> Void

    @State private var currentStep: Step = .intro
    @State private var authorizationState: AuthorizationState = .initial
    @State private var familyControlsErrorMessage: String?
    @State private var isRequestingPermission = false

    private let authorizationService: AuthorizationServicing = AuthorizationService()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                onboardingIntroCard(
                    title: "onboarding.intro.title",
                    message: "onboarding.intro.message"
                )
                .tag(Step.intro)

                onboardingCard(
                    systemImage: "bell.badge.fill",
                    tint: .orange,
                    title: "onboarding.notifications.title",
                    message: "onboarding.notifications.message",
                    detail: authorizationState.notificationPermission.localizedTitle
                )
                .tag(Step.notifications)

                onboardingCard(
                    systemImage: "figure.child.and.lock.fill",
                    tint: .green,
                    title: "onboarding.family.title",
                    message: "onboarding.family.message",
                    detail: authorizationState.familyControlsAuthorization.localizedTitle
                )
                .tag(Step.familyControls)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: currentStep)

            VStack(spacing: 14) {
                pageIndicators
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .background(.thinMaterial)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await refreshAuthorizationState()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshAuthorizationState()
            }
        }
    }

    private func onboardingCard(
        systemImage: String,
        tint: Color,
        title: String,
        message: String,
        detail: String?
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 108, height: 108)

                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 12) {
                Text(L10n.tr(title))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(L10n.tr(message))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            if let detail {
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.background, in: Capsule())
            }

            if let familyControlsErrorMessage, currentStep == .familyControls {
                Text(familyControlsErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
        .padding(.top, 36)
    }

    private func onboardingIntroCard(
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image("LaunchAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

            VStack(spacing: 12) {
                Text(L10n.tr(title))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(L10n.tr(message))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
        .padding(.top, 36)
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.24))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch currentStep {
        case .intro:
            primaryButton(title: L10n.tr("onboarding.common.continue")) {
                currentStep = .notifications
            }
        case .notifications:
            VStack(spacing: 10) {
                primaryButton(title: notificationPrimaryTitle, action: handleNotificationAction)
                secondaryButton(title: L10n.tr("onboarding.notifications.skip")) {
                    currentStep = .familyControls
                }
            }
        case .familyControls:
            VStack(spacing: 10) {
                primaryButton(title: familyControlsPrimaryTitle, action: handleFamilyControlsAction)
                secondaryButton(title: L10n.tr("onboarding.family.finish_later")) {
                    onFinish()
                }
            }
        }
    }

    private var notificationPrimaryTitle: String {
        switch authorizationState.notificationPermission {
        case .authorized:
            return L10n.tr("onboarding.common.continue")
        case .notDetermined:
            return L10n.tr("onboarding.notifications.enable")
        case .denied:
            return L10n.tr("onboarding.notifications.open_settings")
        }
    }

    private var familyControlsPrimaryTitle: String {
        switch authorizationState.familyControlsAuthorization {
        case .approved:
            return L10n.tr("onboarding.family.finish")
        case .notDetermined:
            return L10n.tr("onboarding.family.enable")
        case .denied:
            return L10n.tr("onboarding.family.finish")
        }
    }

    private func handleNotificationAction() {
        switch authorizationState.notificationPermission {
        case .authorized:
            currentStep = .familyControls
        case .notDetermined:
            Task {
                isRequestingPermission = true
                let status = await authorizationService.requestNotificationPermission()
                authorizationState.notificationPermission = status
                isRequestingPermission = false
                if status == .authorized {
                    currentStep = .familyControls
                }
            }
        case .denied:
            openAppSettings()
        }
    }

    private func handleFamilyControlsAction() {
        switch authorizationState.familyControlsAuthorization {
        case .approved, .denied:
            onFinish()
        case .notDetermined:
            Task {
                isRequestingPermission = true
                let result = await authorizationService.requestFamilyControlsAuthorization()
                authorizationState.familyControlsAuthorization = result.status
                familyControlsErrorMessage = result.errorMessage
                isRequestingPermission = false
                if result.status == .approved {
                    onFinish()
                }
            }
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if isRequestingPermission {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isRequestingPermission)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .disabled(isRequestingPermission)
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }

    @MainActor
    private func refreshAuthorizationState() async {
        authorizationState = await authorizationService.currentState()
        if authorizationState.familyControlsAuthorization == .approved {
            familyControlsErrorMessage = nil
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
