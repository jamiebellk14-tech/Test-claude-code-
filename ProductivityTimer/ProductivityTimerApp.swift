import SwiftUI
import SwiftData

// MARK: - Schema versions

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Tag.self, TaskEntry.self, TaskUpdate.self]
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Tag.self, TaskEntry.self, TaskUpdate.self, ScheduledTask.self]
    }
}

// MARK: - Migration plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}

// MARK: - App

@main
struct ProductivityTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Tag.self, TaskEntry.self, TaskUpdate.self, ScheduledTask.self,
                migrationPlan: AppMigrationPlan.self
            )
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
