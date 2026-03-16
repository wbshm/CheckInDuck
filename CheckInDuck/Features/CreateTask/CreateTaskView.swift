import SwiftUI
import FamilyControls

struct CreateTaskView: View {
    @ObservedObject var viewModel: CreateTaskViewModel
    let onSave: (HabitTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isPresentingAppPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $viewModel.taskName)
                }

                Section("Monitored Apps") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(selectionSummaryText)
                            .foregroundStyle(.secondary)
                    }

                    Button("Choose Apps") {
                        isPresentingAppPicker = true
                    }
                }

                Section("Deadline") {
                    Stepper("Hour: \(viewModel.deadlineHour)", value: $viewModel.deadlineHour, in: 0...23)
                    Stepper("Minute: \(viewModel.deadlineMinute)", value: $viewModel.deadlineMinute, in: 0...59)
                }

                Section("Auto Check-in") {
                    Stepper(
                        "Mark completed after \(viewModel.usageThresholdMinutes) min of app usage",
                        value: $viewModel.usageThresholdMinutes,
                        in: 1...180
                    )
                }
            }
            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let task = viewModel.buildTask() else { return }
                        onSave(task)
                        dismiss()
                    }
                    .disabled(viewModel.saveButtonDisabled)
                }
            }
            .familyActivityPicker(isPresented: $isPresentingAppPicker, selection: $selectedApps)
            .onChange(of: selectedApps) { _ in
                syncSelectionData()
            }
        }
    }

    private var selectionSummaryText: String {
        let count =
            selectedApps.applicationTokens.count +
            selectedApps.categoryTokens.count +
            selectedApps.webDomainTokens.count
        return count == 0 ? "None" : "\(count)"
    }

    private func syncSelectionData() {
        let hasSelection =
            !selectedApps.applicationTokens.isEmpty ||
            !selectedApps.categoryTokens.isEmpty ||
            !selectedApps.webDomainTokens.isEmpty

        guard hasSelection else {
            viewModel.selectedAppSelectionData = nil
            return
        }

        viewModel.selectedAppSelectionData = try? JSONEncoder().encode(selectedApps)
    }
}

#Preview {
    CreateTaskView(viewModel: CreateTaskViewModel()) { _ in }
}
