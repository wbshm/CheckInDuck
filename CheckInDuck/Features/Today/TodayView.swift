import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel
    @ObservedObject var subscriptionAccess: SubscriptionAccessService
    @StateObject private var createTaskViewModel = CreateTaskViewModel()
    @State private var isPresentingCreateTask = false
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("New Task") {
                        if subscriptionAccess.canCreateTask(currentTaskCount: viewModel.tasks.count) {
                            createTaskViewModel.resetDraft()
                            isPresentingCreateTask = true
                        } else {
                            isShowingTaskLimitAlert = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        viewModel.reload()
                        viewModel.evaluateDailyStatuses()
                    }
                }
            }
            .sheet(isPresented: $isPresentingCreateTask) {
                CreateTaskView(viewModel: createTaskViewModel) { task in
                    viewModel.addTask(task)
                }
            }
            .alert("Task Limit Reached", isPresented: $isShowingTaskLimitAlert) {
                Button("Upgrade") {
                    isShowingUpgradeView = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Free tier supports up to \(SubscriptionAccessService.freeTaskLimit) task(s). Upgrade to Premium for unlimited tasks."
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
                SummaryChip(title: "Pending", value: viewModel.pendingCount, color: .orange)
                SummaryChip(title: "Completed", value: viewModel.completedCount, color: .green)
                SummaryChip(title: "Missed", value: viewModel.missedCount, color: .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tasksSection: some View {
        Section("Tasks") {
            if viewModel.tasks.isEmpty {
                Text("No tasks yet. Tap New Task to add one.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tasks) { task in
                    TodayTaskRow(task: task, status: viewModel.status(for: task)) {
                        viewModel.markCompleted(taskID: task.id, source: .manual)
                    } onToggleEnabled: {
                        viewModel.toggleEnabled(task: task)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct TodayTaskRow: View {
    let task: HabitTask
    let status: DailyTaskStatus
    let onComplete: () -> Void
    let onToggleEnabled: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.name)
                    .font(.headline)
                Spacer()
                statusTag
            }

            HStack {
                Text("Deadline: \(task.deadline.displayText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(task.isEnabled ? "Disable" : "Enable", action: onToggleEnabled)
                    .buttonStyle(.borderless)
            }

            Text("Auto check-in threshold: \(max(task.usageThresholdSeconds, 1) / 60) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            if status != .completed {
                Button("Mark Completed", action: onComplete)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusTag: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
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
    TodayView(
        viewModel: TodayViewModel(),
        subscriptionAccess: SubscriptionAccessService()
    )
}
