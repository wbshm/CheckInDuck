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
                            record: record
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
                            record: record
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

    private func historyRow(title: String, record: DailyRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(record.status).opacity(0.2))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    statusTag(record.status)
                    if let timeText = viewModel.completionTimeText(for: record),
                       let symbol = viewModel.completionSymbol(for: record) {
                        metaTag(text: timeText, systemImage: symbol)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusTag(_ status: DailyTaskStatus) -> some View {
        Text(status.localizedTitle)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.14))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func metaTag(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .fixedSize(horizontal: false, vertical: true)
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
