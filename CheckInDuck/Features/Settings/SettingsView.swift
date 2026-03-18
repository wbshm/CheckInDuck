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
    @State private var monitoringDiagnostics: MonitoringDiagnostics?

    private let authorizationService: AuthorizationServicing = AuthorizationService()
    private let taskStore = TaskStore()
    private let reminderScheduling: ReminderScheduling = ReminderSchedulingService()
    private let monitoringDiagnosticsService = MonitoringDiagnosticsService()

    init(subscriptionAccess: SubscriptionAccessService) {
        self.subscriptionAccess = subscriptionAccess
        self._storeKitSubscriptionService = StateObject(
            wrappedValue: StoreKitSubscriptionService(subscriptionAccess: subscriptionAccess)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    permissionRow(
                        title: "Notifications",
                        status: authorizationState.notificationPermission.localizedTitle
                    )
                    permissionRow(
                        title: "Family Controls",
                        status: authorizationState.familyControlsAuthorization.localizedTitle
                    )

                    Button("Request Notification Permission") {
                        Task {
                            let status = await authorizationService.requestNotificationPermission()
                            authorizationState.notificationPermission = status
                        }
                    }

                    Button("Request Family Controls Authorization") {
                        Task {
                            let result = await authorizationService.requestFamilyControlsAuthorization()
                            authorizationState.familyControlsAuthorization = result.status
                            familyControlsErrorMessage = result.errorMessage
                        }
                    }

                    if let familyControlsErrorMessage {
                        Text(familyControlsErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Reminders") {
                    Toggle("Enable Reminders", isOn: $remindersEnabled)

                    Stepper(
                        L10n.format("settings.reminders.default_lead_time", reminderOffsetMinutes),
                        value: $reminderOffsetMinutes,
                        in: 5...120,
                        step: 5
                    )
                    .disabled(!remindersEnabled || !subscriptionAccess.isFeatureEnabled(.customReminderWindows))

                    if !subscriptionAccess.isFeatureEnabled(.customReminderWindows) {
                        Text("Premium unlocks custom reminder lead time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink("Upgrade to Premium") {
                            UpgradeView(
                                subscriptionAccess: subscriptionAccess,
                                entryPoint: .reminderCustomization
                            )
                        }
                    }

                    Button("Apply to Existing Tasks") {
                        Task {
                            await applyReminderSettingsToExistingTasks()
                        }
                    }
                    .disabled(isApplyingReminderSettings)

                    if isApplyingReminderSettings {
                        Text("Applying reminder settings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Plan") {
                    if subscriptionAccess.currentTier == .free {
                        NavigationLink("Upgrade to Premium") {
                            UpgradeView(
                                subscriptionAccess: subscriptionAccess,
                                entryPoint: .settings
                            )
                        }
                    }

                    HStack {
                        Text("Current Tier")
                        Spacer()
                        Text(subscriptionAccess.currentTier.localizedTitle)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Free Tier Task Limit")
                        Spacer()
                        Text("\(SubscriptionAccessService.freeTaskLimit)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Free History Window")
                        Spacer()
                        Text(L10n.format("settings.plan.free_history_window_value", SubscriptionAccessService.freeHistoryLookbackDays))
                            .foregroundStyle(.secondary)
                    }

                    if storeKitSubscriptionService.isLoadingProducts {
                        ProgressView("Loading Plans...")
                    } else if storeKitSubscriptionService.products.isEmpty {
                        Text("No subscription products are available yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(storeKitSubscriptionService.products, id: \.id) { product in
                            Button {
                                Task {
                                    await storeKitSubscriptionService.purchase(product)
                                }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    Text(product.displayPrice)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(
                                storeKitSubscriptionService.isProcessingPurchase ||
                                storeKitSubscriptionService.isRestoringPurchases
                            )
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            await storeKitSubscriptionService.restorePurchases()
                        }
                    }
                    .disabled(
                        storeKitSubscriptionService.isProcessingPurchase ||
                        storeKitSubscriptionService.isRestoringPurchases
                    )

                    if storeKitSubscriptionService.isProcessingPurchase {
                        Text("Processing purchase...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if storeKitSubscriptionService.isRestoringPurchases {
                        Text("Restoring purchases...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = storeKitSubscriptionService.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let lastSyncAt = storeKitSubscriptionService.lastSyncAt {
                        Text(L10n.format("settings.plan.last_synced", lastSyncAt.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(L10n.format("settings.plan.storekit_product_ids", SubscriptionProductCatalog.all.joined(separator: " / ")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnostics") {
                    Button("Refresh Diagnostics") {
                        monitoringDiagnostics = monitoringDiagnosticsService.snapshot()
                    }

                    if let monitoringDiagnostics {
                        HStack {
                            Text("App Group Container")
                            Spacer()
                            Text(monitoringDiagnostics.appGroupContainerAvailable ? L10n.tr("settings.diagnostics.available") : L10n.tr("settings.diagnostics.unavailable"))
                                .foregroundStyle(monitoringDiagnostics.appGroupContainerAvailable ? .green : .red)
                        }

                        HStack {
                            Text("Monitored Activities")
                            Spacer()
                            Text("\(monitoringDiagnostics.monitoredActivityNames.count)")
                                .foregroundStyle(.secondary)
                        }

                        if !monitoringDiagnostics.monitoredActivityNames.isEmpty {
                            Text(monitoringDiagnostics.monitoredActivityNames.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Using App Group Defaults")
                            Spacer()
                            Text(monitoringDiagnostics.completionSnapshot.usesAppGroupDefaults ? L10n.tr("common.yes") : L10n.tr("common.no"))
                                .foregroundStyle(monitoringDiagnostics.completionSnapshot.usesAppGroupDefaults ? .green : .red)
                        }

                        HStack {
                            Text("Pending Completion Events")
                            Spacer()
                            Text("\(monitoringDiagnostics.completionSnapshot.todayEventCount)")
                                .foregroundStyle(.secondary)
                        }

                        if let lastIntervalStartAt = monitoringDiagnostics.completionSnapshot.lastIntervalStartAt {
                            Text(L10n.format("settings.diagnostics.last_interval_start", lastIntervalStartAt.formatted(date: .abbreviated, time: .standard)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.tr("settings.diagnostics.last_interval_start_none"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lastIntervalStartTaskID = monitoringDiagnostics.completionSnapshot.lastIntervalStartTaskID {
                            Text(L10n.format("settings.diagnostics.last_interval_task", lastIntervalStartTaskID))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let lastThresholdAt = monitoringDiagnostics.completionSnapshot.lastThresholdAt {
                            Text(L10n.format("settings.diagnostics.last_threshold_callback", lastThresholdAt.formatted(date: .abbreviated, time: .standard)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.tr("settings.diagnostics.last_threshold_callback_none"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lastThresholdTaskID = monitoringDiagnostics.completionSnapshot.lastThresholdTaskID {
                            Text(L10n.format("settings.diagnostics.last_threshold_task", lastThresholdTaskID))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Language") {
                    Button {
                        openAppLanguageSettings()
                    } label: {
                        HStack {
                            Text("App Language")
                            Spacer()
                            Text(currentAppLanguageDisplayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Opens CheckInDuck in the system Settings app. Change Preferred Language there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    Text("CheckInDuck MVP")
                    Text("Privacy-first app usage habit tracker.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: remindersEnabled) { newValue in
                AppPreferences.setRemindersEnabled(newValue)
            }
            .onChange(of: reminderOffsetMinutes) { newValue in
                AppPreferences.setDefaultReminderOffsetMinutes(newValue)
            }
            .onChange(of: subscriptionAccess.currentTier) { newValue in
                if newValue == .free {
                    let fallbackOffset = 30
                    reminderOffsetMinutes = fallbackOffset
                    AppPreferences.setDefaultReminderOffsetMinutes(fallbackOffset)
                }
            }
            .task {
                authorizationState = await authorizationService.currentState()
                familyControlsErrorMessage = nil
                remindersEnabled = AppPreferences.remindersEnabled()
                reminderOffsetMinutes = AppPreferences.defaultReminderOffsetMinutes()
                await refreshSubscriptionSection()
                monitoringDiagnostics = monitoringDiagnosticsService.snapshot()
            }
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, status: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
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

    private func openAppLanguageSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(settingsURL)
    }
}

#Preview {
    SettingsView(subscriptionAccess: SubscriptionAccessService())
}
