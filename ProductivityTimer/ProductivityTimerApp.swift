import SwiftUI
import SwiftData

@main
struct ProductivityTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Tag.self, TaskEntry.self, TaskUpdate.self, ScheduledTask.self,
                             WellbeingSnapshot.self, WellbeingGoal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Store is incompatible with the new schema — wipe and recreate.
            // This happens when new models are added without a prior migration plan.
            try? FileManager.default.removeItem(at: config.url)
            try? FileManager.default.removeItem(at: config.url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: config.url.appendingPathExtension("shm"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
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
