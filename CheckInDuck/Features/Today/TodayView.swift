import SwiftUI
import FamilyControls

struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var subscriptionAccess: SubscriptionAccessService
    @StateObject private var createTaskViewModel = CreateTaskViewModel()
    @StateObject private var editTaskViewModel = CreateTaskViewModel()
    @State private var isPresentingCreateTask = false
    @State private var isPresentingEditTask = false
    @State private var isShowingTaskLimitAlert = false
    @State private var isShowingUpgradeView = false

    var body: some View {
        NavigationStack {
            List {
                summarySection
                tasksSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if subscriptionAccess.canCreateTask(currentTaskCount: viewModel.tasks.count) {
                            createTaskViewModel.resetDraft()
                            isPresentingCreateTask = true
                        } else {
                            isShowingTaskLimitAlert = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Task")
                }
            }
            .sheet(isPresented: $isPresentingCreateTask) {
                CreateTaskView(viewModel: createTaskViewModel) { task in
                    viewModel.addTask(task)
                }
            }
            .sheet(isPresented: $isPresentingEditTask) {
                CreateTaskView(viewModel: editTaskViewModel) { task in
                    viewModel.updateTask(task)
                }
            }
            .alert("Task Limit Reached", isPresented: $isShowingTaskLimitAlert) {
                Button("Upgrade") {
                    isShowingUpgradeView = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    L10n.format(
                        "today.alert.task_limit.message",
                        SubscriptionAccessService.freeTaskLimit
                    )
                )
            }
            .navigationDestination(isPresented: $isShowingUpgradeView) {
                UpgradeView(
                    subscriptionAccess: subscriptionAccess,
                    entryPoint: .taskLimit
                )
            }
            .onAppear {
                viewModel.evaluateDailyStatuses()
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            HStack(spacing: 8) {
                SummaryChip(
                    title: L10n.tr("today.summary.all_short"),
                    value: viewModel.tasks.count,
                    color: .blue,
                    isSelected: viewModel.selectedFilter == .all
                ) {
                    viewModel.selectedFilter = .all
                }

                SummaryChip(
                    title: L10n.tr("today.summary.missed_short"),
                    value: viewModel.missedCount,
                    color: .red,
                    isSelected: viewModel.selectedFilter == .missed
                ) {
                    viewModel.selectedFilter = .missed
                }

                SummaryChip(
                    title: L10n.tr("today.summary.pending_short"),
                    value: viewModel.pendingCount,
                    color: .orange,
                    isSelected: viewModel.selectedFilter == .pending
                ) {
                    viewModel.selectedFilter = .pending
                }

                SummaryChip(
                    title: L10n.tr("today.summary.completed_short"),
                    value: viewModel.completedCount,
                    color: .green,
                    isSelected: viewModel.selectedFilter == .completed
                ) {
                    viewModel.selectedFilter = .completed
                }

                SummaryChip(
                    title: L10n.tr("today.summary.not_today_short"),
                    value: viewModel.notTodayCount,
                    color: .indigo,
                    isSelected: viewModel.selectedFilter == .notToday
                ) {
                    viewModel.selectedFilter = .notToday
                }
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
        }
    }

    private var tasksSection: some View {
        Section("Tasks") {
            if viewModel.tasks.isEmpty {
                Text("No tasks yet. Tap New Task to add one.")
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            } else if viewModel.displayedTasks.isEmpty {
                Text("No tasks match the selected filter.")
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(viewModel.displayedTasks.enumerated()), id: \.element.id) { index, task in
                    if showsNotTodayDivider(before: index, in: viewModel.displayedTasks) {
                        taskGroupDivider(title: L10n.tr("today.task_group.not_today"))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                    }

                    TodayTaskRow(
                        task: task,
                        status: viewModel.displayStatus(for: task),
                        completionTimeText: viewModel.completionTimeText(for: task),
                        completionSymbol: viewModel.completionSymbol(for: task)
                    ) {
                        viewModel.markCompleted(taskID: task.id, source: .manual)
                    } onTap: {
                        presentEditTask(task)
                    } onToggleEnabled: { isEnabled in
                        viewModel.setEnabled(task: task, isEnabled: isEnabled)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            presentEditTask(task)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteTask(id: task.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func presentEditTask(_ task: HabitTask) {
        editTaskViewModel.loadDraft(from: task)
        isPresentingEditTask = true
    }

    private func showsNotTodayDivider(before index: Int, in tasks: [HabitTask]) -> Bool {
        guard index < tasks.count else { return false }
        guard viewModel.displayStatus(for: tasks[index]) == .notToday else { return false }
        guard index > 0 else { return false }
        return viewModel.displayStatus(for: tasks[index - 1]) != .notToday
    }

    private func taskGroupDivider(title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
        }
    }
}

private struct SummaryChip: View {
    let title: String
    let value: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? color : .secondary)
                Text("\(value)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? color : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        isSelected ? color.opacity(0.18) : color.opacity(0.08)
    }
}

private struct TodayTaskRow: View {
    let task: HabitTask
    let status: TodayDisplayStatus
    let completionTimeText: String?
    let completionSymbol: String?
    let onComplete: () -> Void
    let onTap: () -> Void
    let onToggleEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                headerRow
                Spacer(minLength: 12)
                toggleControl
            }

            HStack(alignment: .center, spacing: 12) {
                appRow
                Spacer(minLength: 12)
                statusTag
            }

            HStack(alignment: .top, spacing: 12) {
                metadataRow
                Spacer(minLength: 12)
                if task.isEnabled, status == .pending {
                    actionRow
                }
            }
        }
        .padding(18)
        .background(cardSurface)
        .overlay(cardStroke)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.name)
                .font(.headline)
                .lineLimit(1)

            Text(task.recurrenceSummary())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appRow: some View {
        monitoredAppLabel
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataRow: some View {
        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            metaTag(
                text: TaskTimeFormatter.deadlineBadgeText(task.deadline.displayText),
                systemImage: "clock",
                tint: .secondary
            )
            metaTag(
                text: TaskTimeFormatter.thresholdBadgeText(seconds: task.usageThresholdSeconds),
                systemImage: "timer",
                tint: .blue
            )
            if let completionTimeText, let completionSymbol {
                metaTag(
                    text: completionTimeText,
                    systemImage: completionSymbol,
                    tint: .green
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionRow: some View {
        Button(action: onComplete) {
            Label("Mark Completed", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(.accentColor)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toggleControl: some View {
        Toggle("", isOn: enabledBinding)
            .labelsHidden()
            .tint(.blue)
            .fixedSize()
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { task.isEnabled },
            set: { newValue in
                HapticFeedback.lightImpact()
                onToggleEnabled(newValue)
            }
        )
    }

    @ViewBuilder
    private var monitoredAppLabel: some View {
        if
            let data = task.appSelectionData,
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
            let token = selection.applicationTokens.first
        {
            Label(token)
                .id(token)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusTag: some View {
        Text(statusTitle)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private func metaTag(text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
        .fixedSize(horizontal: false, vertical: true)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(uiColor: .systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }

    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .red
        case .disabled:
            return .secondary
        case .notToday:
            return .blue
        }
    }

    private var statusTitle: String {
        status.localizedTitle
    }
}

#Preview {
    TodayView(
        viewModel: TodayViewModel(),
        subscriptionAccess: SubscriptionAccessService()
    )
}
