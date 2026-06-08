import Foundation
import SwiftData

struct SharedContainer {
    static var schema: Schema {
        Schema([
            Exercise.self,
            TrainingPlan.self,
            PlanGroup.self,
            PlanExercise.self,
            WorkoutSession.self,
            WorkoutSet.self,
            FoodEntry.self,
            DailyLog.self,
            WeightEntry.self,
            StepEntry.self,
            SavedFood.self,
            Recipe.self,
            RecipeIngredient.self
        ])
    }
    
    static var configuration: ModelConfiguration {
        let url = URL.storeURL(for: "group.com.riccardopfeiler.FitTrackPro", databaseName: "default.store")
        return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
    }
    
    static func create() throws -> ModelContainer {
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

extension URL {
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        let fm = FileManager.default
        let defaultStoreURL = URL.applicationSupportDirectory.appendingPathComponent(databaseName)
        
        guard let fileContainer = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            print("WARNING: App Group '\(appGroup)' not found. Widgets will not be able to read data. Make sure App Groups capability is added in Xcode.")
            return defaultStoreURL
        }
        
        let appGroupStoreURL = fileContainer.appendingPathComponent(databaseName)
        
        // Migrate existing DB if needed
        if !fm.fileExists(atPath: appGroupStoreURL.path) && fm.fileExists(atPath: defaultStoreURL.path) {
            print("Migrating database from Application Support to App Group container...")
            do {
                try fm.copyItem(at: defaultStoreURL, to: appGroupStoreURL)
                
                let walURL = URL.applicationSupportDirectory.appendingPathComponent("\(databaseName)-wal")
                let shmURL = URL.applicationSupportDirectory.appendingPathComponent("\(databaseName)-shm")
                
                if fm.fileExists(atPath: walURL.path) {
                    try fm.copyItem(at: walURL, to: fileContainer.appendingPathComponent("\(databaseName)-wal"))
                }
                if fm.fileExists(atPath: shmURL.path) {
                    try fm.copyItem(at: shmURL, to: fileContainer.appendingPathComponent("\(databaseName)-shm"))
                }
                print("Database migration successful.")
            } catch {
                print("Failed to migrate database: \(error)")
            }
        }
        
        return appGroupStoreURL
    }
}
