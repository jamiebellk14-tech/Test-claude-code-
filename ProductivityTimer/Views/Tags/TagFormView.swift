import SwiftUI
import SwiftData

struct TagFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: Color = .blue

    private let tagVM = TagViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag name") {
                    TextField("e.g. Fitness", text: $name)
                }
                Section("Colour") {
                    ColorPicker("Pick a colour", selection: $selectedColor, supportsOpacity: false)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        tagVM.addTag(name: name, colorHex: selectedColor.hexString, context: context)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
