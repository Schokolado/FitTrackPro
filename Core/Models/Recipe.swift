import Foundation
import SwiftData

@Model
final class RecipeIngredient {
    var id: UUID = UUID()
    
    // Verknüpfung zu einem gespeicherten Lebensmittel (optional, da das Lebensmittel gelöscht werden könnte)
    var savedFood: SavedFood?
    
    // Alternativ: Wenn das Lebensmittel aus einer Online-Datenbank kam und nicht gespeichert wurde,
    // oder als Backup der Nährwerte zum Zeitpunkt der Erstellung
    var name: String = ""
    var caloriesPer100g: Double = 0.0
    var proteinPer100g: Double = 0.0
    var carbsPer100g: Double = 0.0
    var fatPer100g: Double = 0.0
    
    var amountGrams: Double = 0.0
    
    // Rückverweis auf das Rezept (für Cascade Delete wichtig in manchen Konstellationen,
    // SwiftData managt Inverse-Beziehungen besser, wenn sie explizit sind)
    var recipe: Recipe?
    
    init(id: UUID = UUID(), savedFood: SavedFood? = nil, name: String, caloriesPer100g: Double, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double, amountGrams: Double) {
        self.id = id
        self.savedFood = savedFood
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.amountGrams = amountGrams
    }
    
    // Berechnete Nährwerte für diese Zutat im Rezept
    var totalCalories: Double { (caloriesPer100g / 100) * amountGrams }
    var totalProtein: Double { (proteinPer100g / 100) * amountGrams }
    var totalCarbs: Double { (carbsPer100g / 100) * amountGrams }
    var totalFat: Double { (fatPer100g / 100) * amountGrams }
}

@Model
final class Recipe {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var portions: Double = 1.0
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient]? = []
    
    init(id: UUID = UUID(), name: String, portions: Double = 1.0) {
        self.id = id
        self.name = name
        self.portions = portions
        self.createdAt = Date()
    }
    
    var totalGrams: Double {
        ingredients?.reduce(0) { $0 + $1.amountGrams } ?? 0.0
    }
    
    var totalCalories: Double {
        ingredients?.reduce(0) { $0 + $1.totalCalories } ?? 0.0
    }
    
    var totalProtein: Double {
        ingredients?.reduce(0) { $0 + $1.totalProtein } ?? 0.0
    }
    
    var totalCarbs: Double {
        ingredients?.reduce(0) { $0 + $1.totalCarbs } ?? 0.0
    }
    
    var totalFat: Double {
        ingredients?.reduce(0) { $0 + $1.totalFat } ?? 0.0
    }
}
