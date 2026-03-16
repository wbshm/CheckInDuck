import SwiftUI
import StoreKit

struct SettingsView: View {
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
                        status: authorizationState.notificationPermission.rawValue
                    )
                    permissionRow(
                        title: "Family Controls",
                        status: authorizationState.familyControlsAuthorization.rawValue
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
                        "Default Reminder Lead Time: \(reminderOffsetMinutes) min",
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
                        Text(subscriptionAccess.currentTier.rawValue.capitalized)
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
                        Text("\(SubscriptionAccessService.freeHistoryLookbackDays) days")
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
                        Text("Last synced: \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("StoreKit product IDs: \(SubscriptionProductCatalog.all.joined(separator: " / "))")
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
                            Text(monitoringDiagnostics.appGroupContainerAvailable ? "Available" : "Unavailable")
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
                            Text(monitoringDiagnostics.completionSnapshot.usesAppGroupDefaults ? "Yes" : "No")
                                .foregroundStyle(monitoringDiagnostics.completionSnapshot.usesAppGroupDefaults ? .green : .red)
                        }

                        HStack {
                            Text("Pending Completion Events")
                            Spacer()
                            Text("\(monitoringDiagnostics.completionSnapshot.todayEventCount)")
                                .foregroundStyle(.secondary)
                        }

                        if let lastIntervalStartAt = monitoringDiagnostics.completionSnapshot.lastIntervalStartAt {
                            Text("Last interval start: \(lastIntervalStartAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Last interval start: none")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lastIntervalStartTaskID = monitoringDiagnostics.completionSnapshot.lastIntervalStartTaskID {
                            Text("Last interval task: \(lastIntervalStartTaskID)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let lastThresholdAt = monitoringDiagnostics.completionSnapshot.lastThresholdAt {
                            Text("Last threshold callback: \(lastThresholdAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Last threshold callback: none")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let lastThresholdTaskID = monitoringDiagnostics.completionSnapshot.lastThresholdTaskID {
                            Text("Last threshold task: \(lastThresholdTaskID)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            Text(status.capitalized)
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
}

#Preview {
    SettingsView(subscriptionAccess: SubscriptionAccessService())
}
