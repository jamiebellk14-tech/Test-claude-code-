import SwiftUI
import SwiftData

@main
struct ProductivityTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Tag.self, TaskEntry.self, TaskUpdate.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .onAppear {
                    seedDefaultTagsIfNeeded()
                }
        }
    }

    private func seedDefaultTagsIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Tag>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        Tag.defaults.forEach { context.insert($0) }
        try? context.save()
    }
}
