import Foundation
import SwiftData

struct SeedExercise: Codable {
    let name: String
    let category: String
    let defaultRestDuration: Double
    let sortOrder: Int
}

@MainActor
class SeedDataService {
    static let shared = SeedDataService()
    private init() {}
    
    func seedExercisesIfNeeded(context: ModelContext) {
        let hasSeeded = UserDefaults.standard.bool(forKey: AppStorageKeys.hasSeededExercises)
        guard !hasSeeded else { return }
        
        let locale = Locale.current.language.languageCode?.identifier == "de" ? "de" : "en"
        let fileName = "DefaultExercises_\(locale)"
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seedData = try? JSONDecoder().decode([SeedExercise].self, from: data) else {
            print("Failed to load seed data from \(fileName).json")
            return
        }
        
        for seed in seedData {
            let category = seed.category
            let exercise = Exercise(
                name: seed.name,
                category: category,
                defaultRestDuration: seed.defaultRestDuration,
                isCustom: false,
                sortOrder: seed.sortOrder
            )
            context.insert(exercise)
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: AppStorageKeys.hasSeededExercises)
            print("Successfully seeded exercises.")
        } catch {
            print("Failed to save seed data: \(error)")
        }
    }
}
