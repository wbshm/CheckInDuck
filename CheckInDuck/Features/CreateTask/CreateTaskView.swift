import SwiftUI
import FamilyControls

struct CreateTaskView: View {
    @ObservedObject var viewModel: CreateTaskViewModel
    let onSave: (HabitTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isPresentingAppPicker = false

    init(viewModel: CreateTaskViewModel, onSave: @escaping (HabitTask) -> Void) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onSave = onSave

        let initialSelection: FamilyActivitySelection
        if
            let data = viewModel.selectedAppSelectionData,
            let decodedSelection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        {
            initialSelection = decodedSelection
        } else {
            initialSelection = FamilyActivitySelection()
        }
        self._selectedApps = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $viewModel.taskName)
                }

                Section("Monitored Apps") {
                    Button {
                        isPresentingAppPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Text("Choose App")

                            Spacer(minLength: 16)

                            HStack(spacing: 8) {
                                appSelectionValue
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Deadline") {
                    DatePicker(
                        "Time",
                        selection: deadlineDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Repeat") {
                    Picker("Pattern", selection: $viewModel.recurrence) {
                        ForEach(TaskRecurrence.allCases) { recurrence in
                            Text(recurrence.localizedTitle)
                                .tag(recurrence)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.recurrence != .daily {
                        DatePicker(
                            "Date",
                            selection: recurrenceAnchorDateBinding,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
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
            .navigationTitle(viewModel.isEditing ? "Edit Task" : "Create Task")
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
            .onChange(of: viewModel.usageThresholdMinutes) { _ in
                HapticFeedback.selectionChanged()
            }
        }
    }

    @ViewBuilder
    private var appSelectionValue: some View {
        if let token = selectedApps.applicationTokens.first {
            Label(token)
                .id(token)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        } else {
            Text("No apps selected yet.")
                .foregroundStyle(.secondary)
        }
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

    private var recurrenceAnchorDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.recurrenceAnchorDate },
            set: { newDate in
                viewModel.recurrenceAnchorDate = Calendar.current.startOfDay(for: newDate)
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
