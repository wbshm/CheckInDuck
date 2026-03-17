import SwiftUI
import FamilyControls

struct AppSelectionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding private var selection: FamilyActivitySelection
    @State private var workingSelection: FamilyActivitySelection

    init(selection: Binding<FamilyActivitySelection>) {
        _selection = selection
        _workingSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $workingSelection)
                .navigationTitle("Choose Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            selection = workingSelection
                            dismiss()
                        }
                    }
                }
        }
        .onAppear {
            workingSelection = selection
        }
    }
}
