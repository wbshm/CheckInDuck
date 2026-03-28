import SwiftUI

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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SummaryChip(
                        title: L10n.tr("today.filter.all"),
                        value: viewModel.scheduledTasks.count,
                        color: .blue,
                        isSelected: viewModel.selectedFilter == .all
                    ) {
                        viewModel.selectedFilter = .all
                    }

                    SummaryChip(
                        title: L10n.tr("status.missed"),
                        value: viewModel.missedCount,
                        color: .red,
                        isSelected: viewModel.selectedFilter == .missed
                    ) {
                        viewModel.selectedFilter = .missed
                    }

                    SummaryChip(
                        title: L10n.tr("status.pending"),
                        value: viewModel.pendingCount,
                        color: .orange,
                        isSelected: viewModel.selectedFilter == .pending
                    ) {
                        viewModel.selectedFilter = .pending
                    }

                    SummaryChip(
                        title: L10n.tr("status.completed"),
                        value: viewModel.completedCount,
                        color: .green,
                        isSelected: viewModel.selectedFilter == .completed
                    ) {
                        viewModel.selectedFilter = .completed
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tasksSection: some View {
        Section("Tasks") {
            if viewModel.tasks.isEmpty {
                Text("No tasks yet. Tap New Task to add one.")
                    .foregroundStyle(.secondary)
            } else if viewModel.scheduledTasks.isEmpty {
                Text("No tasks scheduled for today.")
                    .foregroundStyle(.secondary)
            } else if viewModel.displayedTasks.isEmpty {
                Text("No tasks match the selected filter.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.displayedTasks) { task in
                    TodayTaskRow(
                        task: task,
                        status: viewModel.visibleStatus(for: task),
                        completionTimeText: viewModel.completionTimeText(for: task),
                        completionSymbol: viewModel.completionSymbol(for: task)
                    ) {
                        viewModel.markCompleted(taskID: task.id, source: .manual)
                    } onToggleEnabled: { isEnabled in
                        viewModel.setEnabled(task: task, isEnabled: isEnabled)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editTaskViewModel.loadDraft(from: task)
                            isPresentingEditTask = true
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
                }
            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? color : .secondary)
                Text("\(value)")
                    .font(.headline)
                    .foregroundStyle(isSelected ? color : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        isSelected ? color.opacity(0.18) : color.opacity(0.08)
    }
}

private struct TodayTaskRow: View {
    let task: HabitTask
    let status: DailyTaskStatus?
    let completionTimeText: String?
    let completionSymbol: String?
    let onComplete: () -> Void
    let onToggleEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.name)
                    .font(.headline)
                Spacer()
                statusTag
            }

            HStack {
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
                Spacer(minLength: 8)
                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(.blue)
                    .fixedSize()
            }

            if task.isEnabled, status != .completed {
                Button("Mark Completed", action: onComplete)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
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

    private var statusTag: some View {
        Text(statusTitle)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

    private var statusColor: Color {
        switch status {
        case nil:
            return .secondary
        case .pending:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .red
        }
    }

    private var statusTitle: String {
        status?.localizedTitle ?? L10n.tr("today.status.disabled")
    }
}

#Preview {
    TodayView(
        viewModel: TodayViewModel(),
        subscriptionAccess: SubscriptionAccessService()
    )
}
