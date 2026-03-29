import Foundation
import SwiftData

struct TagViewModel {

    func addTag(name: String, colorHex: String, context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorHex: colorHex)
        context.insert(tag)
        try? context.save()
    }

    func deleteTag(_ tag: Tag, context: ModelContext) {
        guard !tag.isDefault else { return }
        context.delete(tag)
        try? context.save()
    }
}
