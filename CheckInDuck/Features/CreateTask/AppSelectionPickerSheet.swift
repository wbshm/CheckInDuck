import SwiftUI
import FamilyControls

struct AppSelectionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding private var selection: FamilyActivitySelection
    @State private var workingSelection: FamilyActivitySelection
    @State private var previousSelection: FamilyActivitySelection

    init(selection: Binding<FamilyActivitySelection>) {
        _selection = selection
        _workingSelection = State(initialValue: selection.wrappedValue)
        _previousSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $workingSelection)
                .navigationTitle("Choose App")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: workingSelection) { newValue in
                    let normalized = normalizeSelection(newValue, previous: previousSelection)
                    if normalized != newValue {
                        workingSelection = normalized
                        previousSelection = normalized
                    } else {
                        previousSelection = newValue
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            selection = workingSelection
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(workingSelection.applicationTokens.isEmpty)
                    }
                }
        }
        .onAppear {
            let normalized = normalizeSelection(selection, previous: selection)
            workingSelection = normalized
            previousSelection = normalized
        }
    }

    private func normalizeSelection(
        _ candidate: FamilyActivitySelection,
        previous: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        let applications = candidate.applicationTokens

        let keptApp =
            applications.count <= 1
            ? applications.first
            : applications.subtracting(previous.applicationTokens).first ?? applications.first

        var singleSelection = FamilyActivitySelection(includeEntireCategory: false)
        if let keptApp {
            singleSelection.applicationTokens = [keptApp]
        }
        return singleSelection
    }
}
