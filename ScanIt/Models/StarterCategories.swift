import SwiftUI

/// How a category looks: its name, SF Symbol and tag colors.
/// In M1 these seed the user's editable categories in the database.
struct CategoryStyle: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
    /// Text color of the category tag.
    let foreground: Color
    /// Background color of the category tag.
    let background: Color
}

enum StarterCategories {
    static let all: [CategoryStyle] = [
        CategoryStyle(id: "receipts", name: "Receipts", symbol: "receipt",
                      foreground: Color(light: 0x0F766E, dark: 0x5EEAD4),
                      background: Color(light: 0xDDF4F0, dark: 0x0E3532)),
        CategoryStyle(id: "bills", name: "Bills", symbol: "doc.text",
                      foreground: Color(light: 0x1D4ED8, dark: 0x7FB0FF),
                      background: Color(light: 0xE3ECFF, dark: 0x13284D)),
        CategoryStyle(id: "medical", name: "Medical", symbol: "cross.case",
                      foreground: Color(light: 0xB91C1C, dark: 0xFF8F8F),
                      background: Color(light: 0xFDE6E6, dark: 0x4A1616)),
        CategoryStyle(id: "insurance", name: "Insurance", symbol: "shield.lefthalf.filled",
                      foreground: Color(light: 0x3730A3, dark: 0x9DA8FF),
                      background: Color(light: 0xE6E8FF, dark: 0x1E2152)),
        CategoryStyle(id: "legal", name: "Legal", symbol: "building.columns",
                      foreground: Color(light: 0x6D28D9, dark: 0xC4A8FF),
                      background: Color(light: 0xEFE7FF, dark: 0x2E1A52)),
        CategoryStyle(id: "id", name: "ID", symbol: "person.text.rectangle",
                      foreground: Color(light: 0xC2410C, dark: 0xFDBA74),
                      background: Color(light: 0xFFEDD5, dark: 0x4A2208)),
        CategoryStyle(id: "school", name: "School", symbol: "backpack",
                      foreground: Color(light: 0x92400E, dark: 0xFFC266),
                      background: Color(light: 0xFDF0DC, dark: 0x4A2E08)),
        CategoryStyle(id: "personal", name: "Personal", symbol: "heart.text.square",
                      foreground: Color(light: 0x9D174D, dark: 0xFF9CCB),
                      background: Color(light: 0xFCE5F0, dark: 0x4A1530)),
    ]
}
