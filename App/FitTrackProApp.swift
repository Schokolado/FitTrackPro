import SwiftUI
import SwiftData

@main
struct FitTrackProApp: App {
    
    // Konfiguration für SwiftData + CloudKit Sync
    // Sobald wir die echten Models in Milestone 1 haben, tragen wir sie hier ein.
    // var sharedModelContainer: ModelContainer = {
    //     let schema = Schema([
    //         // Exercise.self, TrainingPlan.self, etc.
    //     ])
    //     let modelConfiguration = ModelConfiguration(
    //         schema: schema,
    //         isStoredInMemoryOnly: false,
    //         cloudKitDatabase: .automatic // iCloud Container ID: iCloud.com.fittrackpro.app
    //     )
    //
    //     do {
    //         return try ModelContainer(for: schema, configurations: [modelConfiguration])
    //     } catch {
    //         fatalError("Could not create ModelContainer: \(error)")
    //     }
    // }()

    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        // .modelContainer(sharedModelContainer)
    }
}
