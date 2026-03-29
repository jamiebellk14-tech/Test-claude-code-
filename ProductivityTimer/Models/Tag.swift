import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var isDefault: Bool

    @Relationship(deleteRule: .nullify, inverse: \TaskEntry.tag)
    var tasks: [TaskEntry] = []

    init(id: UUID = UUID(), name: String, colorHex: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
    }

    static var defaults: [Tag] {
        [
            Tag(name: "Work",      colorHex: "#4A90E2", isDefault: true),
            Tag(name: "Personal",  colorHex: "#7ED321", isDefault: true),
            Tag(name: "Housework", colorHex: "#F5A623", isDefault: true),
        ]
    }
}
