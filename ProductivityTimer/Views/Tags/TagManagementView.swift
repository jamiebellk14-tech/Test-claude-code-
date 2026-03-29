import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var context
    @State private var showAddSheet = false

    private let tagVM = TagViewModel()

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                TagFormView()
            }
        }
    }
}
