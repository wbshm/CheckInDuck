import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var subscriptionAccess: SubscriptionAccessService
    @StateObject private var storeKitSubscriptionService: StoreKitSubscriptionService
    @State private var authorizationState: AuthorizationState = .initial
    @State private var familyControlsErrorMessage: String?
    @State private var remindersEnabled = AppPreferences.remindersEnabled()
    @State private var reminderOffsetMinutes = AppPreferences.defaultReminderOffsetMinutes()
    @State private var isApplyingReminderSettings = false
    @State private var hasLoadedReminderSettings = false
    @State private var pendingReminderApplyTask: Task<Void, Never>?

    private let authorizationService: AuthorizationServicing = AuthorizationService()
    private let taskStore = TaskStore()
    private let reminderScheduling: ReminderScheduling = ReminderSchedulingService()

    init(subscriptionAccess: SubscriptionAccessService) {
        self.subscriptionAccess = subscriptionAccess
        self._storeKitSubscriptionService = StateObject(
            wrappedValue: StoreKitSubscriptionService(subscriptionAccess: subscriptionAccess)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                premiumSection
                remindersSection
                permissionsSection
                languageSection
                aboutSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L10n.tr("Settings"))
            .onChange(of: remindersEnabled) { newValue in
                AppPreferences.setRemindersEnabled(newValue)
                scheduleReminderSettingsSyncIfReady()
            }
            .onChange(of: reminderOffsetMinutes) { newValue in
                AppPreferences.setDefaultReminderOffsetMinutes(newValue)
                scheduleReminderSettingsSyncIfReady()
            }
            .onChange(of: subscriptionAccess.currentTier) { newValue in
                if newValue == .free {
                    let fallbackOffset = 30
                    reminderOffsetMinutes = fallbackOffset
                    AppPreferences.setDefaultReminderOffsetMinutes(fallbackOffset)
                    scheduleReminderSettingsSyncIfReady()
                }
            }
            .task {
                authorizationState = await authorizationService.currentState()
                familyControlsErrorMessage = nil
                remindersEnabled = AppPreferences.remindersEnabled()
                reminderOffsetMinutes = AppPreferences.defaultReminderOffsetMinutes()
                await refreshSubscriptionSection()
                hasLoadedReminderSettings = true
            }
        }
    }

    private var premiumSection: some View {
        Section(L10n.tr("Premium")) {
            settingsCard {
                if subscriptionAccess.currentTier == .free {
                    cardRow {
                        NavigationLink {
                            UpgradeView(
                                subscriptionAccess: subscriptionAccess,
                                entryPoint: .settings
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("upgrade.entry.settings.title"))
                                    .font(.headline)
                                Text(L10n.tr("settings.plan.summary.free"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    cardRow {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("settings.plan.summary.active"))
                                .font(.headline)
                            Text(L10n.tr("settings.plan.summary.active_detail"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                cardDivider

                cardRow {
                    settingValueRow(
                        title: L10n.tr("Current Tier"),
                        value: subscriptionAccess.currentTier.localizedTitle
                    )
                }

                cardDivider

                if subscriptionAccess.currentTier == .free {
                    cardRow {
                        settingValueRow(
                            title: L10n.tr("Free Tier Task Limit"),
                            value: "\(SubscriptionAccessService.freeTaskLimit)"
                        )
                    }

                    cardDivider

                    cardRow {
                        settingValueRow(
                            title: L10n.tr("Free History Window"),
                            value: L10n.format(
                                "settings.plan.free_history_window_value",
                                SubscriptionAccessService.freeHistoryLookbackDays
                            )
                        )
                    }
                } else {
                    cardRow {
                        settingValueRow(
                            title: L10n.tr("Task Limit"),
                            value: L10n.tr("settings.plan.unlimited")
                        )
                    }

                    cardDivider

                    cardRow {
                        settingValueRow(
                            title: L10n.tr("History"),
                            value: L10n.tr("settings.plan.full_history")
                        )
                    }
                }

                if storeKitSubscriptionService.isLoadingProducts {
                    cardDivider

                    cardRow {
                        ProgressView("Loading Plans...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if subscriptionAccess.currentTier == .free {
                    if storeKitSubscriptionService.products.isEmpty {
                        cardDivider

                        cardRow {
                            Text("No subscription products are available yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(storeKitSubscriptionService.products, id: \.id) { product in
                            cardDivider

                            cardRow {
                                Button {
                                    Task {
                                        await storeKitSubscriptionService.purchase(product)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.displayName)
                                            Text(L10n.tr("settings.plan.unlock_all"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .disabled(
                                    storeKitSubscriptionService.isProcessingPurchase ||
                                    storeKitSubscriptionService.isRestoringPurchases
                                )
                            }
                        }
                    }
                }

                cardDivider

                cardRow {
                    Button("Restore Purchases") {
                        Task {
                            await storeKitSubscriptionService.restorePurchases()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .disabled(
                        storeKitSubscriptionService.isProcessingPurchase ||
                        storeKitSubscriptionService.isRestoringPurchases
                    )
                }

                if storeKitSubscriptionService.isProcessingPurchase {
                    cardDivider

                    cardRow {
                        Text("Processing purchase...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if storeKitSubscriptionService.isRestoringPurchases {
                    cardDivider

                    cardRow {
                        Text("Restoring purchases...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let errorMessage = storeKitSubscriptionService.errorMessage {
                    cardDivider

                    cardRow {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let lastSyncAt = storeKitSubscriptionService.lastSyncAt {
                    cardDivider

                    cardRow {
                        Text(L10n.format("settings.plan.last_synced", lastSyncAt.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var remindersSection: some View {
        Section(L10n.tr("Reminders")) {
            settingsCard {
                cardRow {
                    Toggle("Enable Reminders", isOn: $remindersEnabled)
                }

                cardDivider

                cardRow {
                    Stepper(
                        L10n.format("settings.reminders.default_lead_time", reminderOffsetMinutes),
                        value: $reminderOffsetMinutes,
                        in: 5...120,
                        step: 5
                    )
                    .disabled(!remindersEnabled || !subscriptionAccess.isFeatureEnabled(.customReminderWindows))
                }

                if !subscriptionAccess.isFeatureEnabled(.customReminderWindows) {
                    cardDivider

                    cardRow {
                        Text("Premium unlocks custom reminder lead time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    cardDivider

                    cardRow {
                        NavigationLink("Upgrade to Premium") {
                            UpgradeView(
                                subscriptionAccess: subscriptionAccess,
                                entryPoint: .reminderCustomization
                            )
                        }
                    }
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section(L10n.tr("Permissions")) {
            settingsCard {
                cardRow {
                    permissionActionRow(
                        systemImage: "bell.badge",
                        title: L10n.tr("Notifications"),
                        detail: "settings.permissions.notifications.detail",
                        status: authorizationState.notificationPermission.localizedTitle,
                        actionTitle: notificationActionTitle,
                        action: handleNotificationPermissionAction
                    )
                }

                cardDivider

                cardRow {
                    permissionActionRow(
                        systemImage: "figure.child.and.lock",
                        title: L10n.tr("Family Controls"),
                        detail: "settings.permissions.family.detail",
                        status: authorizationState.familyControlsAuthorization.localizedTitle,
                        actionTitle: familyControlsActionTitle,
                        action: handleFamilyControlsAction
                    )
                }

                if let familyControlsErrorMessage {
                    cardDivider

                    cardRow {
                        Text(familyControlsErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var languageSection: some View {
        Section(L10n.tr("Language")) {
            settingsCard {
                cardRow {
                    Button {
                        openAppSettings()
                    } label: {
                        HStack {
                            Text("App Language")
                            Spacer()
                            Text(currentAppLanguageDisplayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(L10n.tr("About")) {
            settingsCard {
                cardRow {
                    settingValueRow(title: L10n.tr("Version"), value: appVersionText)
                }
            }
        }
    }

    private func settingValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func cardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private var cardDivider: some View {
        Divider()
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func permissionActionRow(
        systemImage: String,
        title: String,
        detail: LocalizedStringKey,
        status: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                        Spacer()
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func applyReminderSettingsToExistingTasks() async {
        isApplyingReminderSettings = true
        defer { isApplyingReminderSettings = false }

        let enabled = remindersEnabled
        let offset = reminderOffsetMinutes

        var tasks = taskStore.loadAll()
        tasks = tasks.map { task in
            var updatedTask = task
            updatedTask.reminderConfig = ReminderConfig(isEnabled: enabled, offsetsInMinutes: [offset])
            updatedTask.updatedAt = Date()
            return updatedTask
        }
        taskStore.saveAll(tasks)

        for task in tasks {
            if enabled && task.isEnabled {
                await reminderScheduling.scheduleReminders(for: task)
            } else {
                await reminderScheduling.cancelReminders(for: task.id)
            }
        }
    }

    private func scheduleReminderSettingsSyncIfReady() {
        guard hasLoadedReminderSettings else { return }

        pendingReminderApplyTask?.cancel()
        pendingReminderApplyTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await applyReminderSettingsToExistingTasks()
        }
    }

    @MainActor
    private func refreshSubscriptionSection() async {
        if storeKitSubscriptionService.products.isEmpty {
            await storeKitSubscriptionService.loadProducts()
        }
        await storeKitSubscriptionService.refreshSubscriptionStatus()
    }

    private var currentAppLanguageDisplayName: String {
        let identifier =
            Bundle.main.preferredLocalizations.first ??
            Locale.preferredLanguages.first ??
            Locale.current.identifier
        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    private var notificationActionTitle: String? {
        switch authorizationState.notificationPermission {
        case .authorized:
            return nil
        case .notDetermined:
            return L10n.tr("Enable")
        case .denied:
            return L10n.tr("Open Settings")
        }
    }

    private var familyControlsActionTitle: String? {
        switch authorizationState.familyControlsAuthorization {
        case .approved:
            return nil
        case .notDetermined:
            return L10n.tr("Enable")
        case .denied:
            return L10n.tr("Try Again")
        }
    }

    private func handleNotificationPermissionAction() {
        switch authorizationState.notificationPermission {
        case .authorized:
            return
        case .notDetermined:
            Task {
                let status = await authorizationService.requestNotificationPermission()
                authorizationState.notificationPermission = status
            }
        case .denied:
            openAppSettings()
        }
    }

    private func handleFamilyControlsAction() {
        Task {
            let result = await authorizationService.requestFamilyControlsAuthorization()
            authorizationState.familyControlsAuthorization = result.status
            familyControlsErrorMessage = result.errorMessage
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(settingsURL)
    }

    private var appVersionText: String {
        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(shortVersion)"
    }
}

#Preview {
    SettingsView(subscriptionAccess: SubscriptionAccessService())
}
