import SwiftData
import SwiftUI

@main
struct ScanItApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try AppSchema.makeContainer()
        } catch {
            fatalError("Couldn't open the ScanIt database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { DocumentStore(context: container.mainContext).seedCategoriesIfNeeded() }
        }
        .modelContainer(container)
    }
}
