import SwiftUI

@MainActor
struct HistoryView: View {
    @ObservedObject private var subscriptionAccess: SubscriptionAccessService
    @StateObject private var viewModel: HistoryViewModel

    init(subscriptionAccess: SubscriptionAccessService) {
        self._subscriptionAccess = ObservedObject(wrappedValue: subscriptionAccess)
        _viewModel = StateObject(
            wrappedValue: HistoryViewModel(subscriptionAccess: subscriptionAccess)
        )
    }

    init(
        viewModel: HistoryViewModel,
        subscriptionAccess: SubscriptionAccessService
    ) {
        self._subscriptionAccess = ObservedObject(wrappedValue: subscriptionAccess)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                controlsSection

                if viewModel.filteredRecords.isEmpty {
                    emptyState
                } else {
                    recordsSection
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .onAppear {
                viewModel.reload()
            }
        }
    }

    private var controlsSection: some View {
        Section("View") {
            Picker("Display", selection: $viewModel.displayMode) {
                ForEach(HistoryDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                Button("All Tasks") {
                    viewModel.selectedTaskID = nil
                }

                ForEach(viewModel.availableTasks) { task in
                    Button(task.name) {
                        viewModel.selectedTaskID = task.id
                    }
                }
            } label: {
                HStack {
                    Text("Task Filter")
                    Spacer()
                    Text(selectedTaskFilterText)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!viewModel.isTaskFilterEnabled)

            if !subscriptionAccess.canViewFullHistory() {
                Text(L10n.format("history.free_tier_window", SubscriptionAccessService.freeHistoryLookbackDays))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink("Upgrade to Premium") {
                    UpgradeView(
                        subscriptionAccess: subscriptionAccess,
                        entryPoint: .historyLimit
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        switch viewModel.displayMode {
        case .byDay:
            ForEach(viewModel.daySections) { section in
                Section(section.date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(section.records) { record in
                        historyRow(
                            title: viewModel.taskName(for: record.taskId),
                            subtitle: rowSubtitle(for: record),
                            status: record.status
                        )
                    }
                }
            }
        case .byTask:
            ForEach(viewModel.taskSections) { section in
                Section(section.taskName) {
                    ForEach(section.records) { record in
                        historyRow(
                            title: record.date.formatted(date: .abbreviated, time: .omitted),
                            subtitle: rowSubtitle(for: record),
                            status: record.status
                        )
                    }
                }
            }
        }
    }

    private var selectedTaskFilterText: String {
        guard let selectedTaskID = viewModel.selectedTaskID else {
            return L10n.tr("history.all_tasks")
        }
        return viewModel.taskName(for: selectedTaskID)
    }

    private var emptyState: some View {
        Section {
            Text("No completed or missed records yet.")
                .foregroundStyle(.secondary)
        }
    }

    private func rowSubtitle(for record: DailyRecord) -> String {
        let completionText = viewModel.completionDetailText(for: record)
        return L10n.format("history.row_subtitle", record.status.localizedTitle, completionText)
    }

    private func historyRow(title: String, subtitle: String, status: DailyTaskStatus) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(status).opacity(0.2))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: DailyTaskStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .red
        }
    }
}

#Preview {
    HistoryView(subscriptionAccess: SubscriptionAccessService())
}
