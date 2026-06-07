import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast  = "Frühstück"
    case lunch      = "Mittagessen"
    case dinner     = "Abendessen"
    case snack      = "Snack"
}

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var name: String = ""
    var barcode: String?
    var timestamp: Date = Date()
    var mealType: MealType = MealType.snack
    
    // Nährwerte
    var amountGrams: Double = 0.0
    var calories: Double = 0.0
    var proteinGrams: Double = 0.0
    var carbsGrams: Double = 0.0
    var fatGrams: Double = 0.0
    var syncedToHealthKit: Bool = false
    
    var dailyLog: DailyLog?

    init(id: UUID = UUID(), name: String = "", barcode: String? = nil, timestamp: Date = Date(), mealType: MealType = .snack, amountGrams: Double = 0.0, calories: Double = 0.0, proteinGrams: Double = 0.0, carbsGrams: Double = 0.0, fatGrams: Double = 0.0, syncedToHealthKit: Bool = false, dailyLog: DailyLog? = nil) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.timestamp = timestamp
        self.mealType = mealType
        self.amountGrams = amountGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.syncedToHealthKit = syncedToHealthKit
        self.dailyLog = dailyLog
    }
}
