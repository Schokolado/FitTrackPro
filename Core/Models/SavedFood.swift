import Foundation
import SwiftData

@Model
final class SavedFood {
    var id: UUID = UUID()
    var name: String = ""
    var barcode: String?
    var createdAt: Date = Date()
    
    // Nährwerte pro 100g oder pro Portion
    var caloriesPer100g: Double = 0.0
    var proteinPer100g: Double = 0.0
    var carbsPer100g: Double = 0.0
    var fatPer100g: Double = 0.0
    
    init(id: UUID = UUID(), name: String, barcode: String? = nil, caloriesPer100g: Double, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.createdAt = Date()
    }
}
