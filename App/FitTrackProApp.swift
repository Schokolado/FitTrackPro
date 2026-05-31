import SwiftUI
import SwiftData

@main
struct FitTrackProApp: App {
    
    // Konfiguration für SwiftData + CloudKit Sync
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            TrainingPlan.self,
            PlanExercise.self,
            WorkoutSession.self,
            WorkoutSet.self,
            FoodEntry.self,
            DailyLog.self,
            WeightEntry.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // iCloud Container ID: iCloud.com.fittrackpro.app
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(themeManager)
                .environment(WorkoutManager.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}
