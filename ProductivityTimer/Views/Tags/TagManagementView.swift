import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var context
    @State private var showAddSheet = false
    @State private var editMode: EditMode = .inactive

    private let tagVM = TagViewModel()

    var body: some View {
        VStack(spacing: 0) {
            BrandNavBar.titled(
                "Tags",
                leading: AnyView(
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#00bf63"))
                    .padding(.leading, 4)
                ),
                trailing: AnyView(
                    TactileNavButton(icon: "plus") { showAddSheet = true }
                )
            )

            List {
                ForEach(tags) { tag in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 14, height: 14)
                        Text(tag.name)
                        Spacer()
                        if tag.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardRow()
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let tag = tags[index]
                        if !tag.isDefault {
                            tagVM.deleteTag(tag, context: context)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        }
        .sheet(isPresented: $showAddSheet) {
            TagFormView()
        }
    }
}
