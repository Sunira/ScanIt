import SwiftUI

/// Placeholder for the shared Family space, which arrives in V2.
struct FamilyComingSoonView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Family is coming in V2", systemImage: "person.2")
            } description: {
                Text("Share documents with your family in a shared space, synced through iCloud.")
            }
            .navigationTitle("Family")
        }
    }
}

#Preview {
    FamilyComingSoonView()
}
