import SwiftData
import SwiftUI

/// The Settings tab. Most rows become live in later milestones (noted beside each).
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    LabeledContent("Require Face ID", value: "Coming in M5")
                }
                Section {
                    LabeledContent("Anthropic API key", value: "Not set")
                    LabeledContent("Describe regular photos", value: "On")
                } header: {
                    Text("AI")
                } footer: {
                    Text("Documents send only their text to the AI. Regular photos are sent as images so they can be described.")
                }
                Section("Library") {
                    NavigationLink("Categories") { CategoriesView() }
                    LabeledContent("iCloud sync", value: "Coming in M7")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Lists the categories. Editing arrives in M4.
struct CategoriesView: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var body: some View {
        List(categories) { category in
            Label {
                Text(category.name)
            } icon: {
                Image(systemName: category.symbol)
                    .foregroundStyle(category.style.foreground)
            }
        }
        .navigationTitle("Categories")
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(try! AppSchema.makeContainer(inMemory: true))
}
