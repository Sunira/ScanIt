import SwiftUI

/// The small colored category label shown on document rows and screens.
struct CategoryTag: View {
    let category: CategoryStyle

    var body: some View {
        Text(category.name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(category.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(category.background, in: .rect(cornerRadius: 6))
    }
}

/// A filter button in the row along the top of the Documents list.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                            in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(StarterCategories.all) { CategoryTag(category: $0) }
        FilterChip(title: "All", isSelected: true) {}
    }
    .padding()
}
