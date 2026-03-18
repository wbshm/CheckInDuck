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

                    if !selectedApps.applicationTokens.isEmpty {
                        ForEach(Array(selectedApps.applicationTokens), id: \.self) { token in
                            Label(token)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                    } else {
                        Text("No apps selected yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !selectedApps.categoryTokens.isEmpty || !selectedApps.webDomainTokens.isEmpty {
                        Text(
                            L10n.format(
                                "create_task.selection.categories_websites",
                                selectedApps.categoryTokens.count,
                                selectedApps.webDomainTokens.count
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Deadline") {
                    DatePicker(
                        "Time",
                        selection: deadlineDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Auto Check-in") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Mark completed after app usage")
                            Spacer()
                            Text(L10n.format("common.minutes.short", viewModel.usageThresholdMinutes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: usageThresholdMinutesBinding,
                            in: 1...60,
                            step: 1
                        )
                        HStack {
                            Text("1 min")
                            Spacer()
                            Text("60 min")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
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
            .sheet(isPresented: $isPresentingAppPicker) {
                AppSelectionPickerSheet(selection: $selectedApps)
            }
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
        return count == 0 ? L10n.tr("common.none") : "\(count)"
    }

    private var deadlineDateBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = viewModel.deadlineHour
                components.minute = viewModel.deadlineMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                viewModel.deadlineHour = components.hour ?? 21
                viewModel.deadlineMinute = components.minute ?? 0
            }
        )
    }

    private var usageThresholdMinutesBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.usageThresholdMinutes) },
            set: { newValue in
                viewModel.usageThresholdMinutes = Int(newValue.rounded())
            }
        )
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
