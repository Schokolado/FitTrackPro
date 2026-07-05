import SwiftUI
import SwiftData

struct SavedFoodListView: View {
    var foods: [SavedFood]
    var onIngredientSelected: ((String, Double, Double, Double, Double, Double) -> Void)?
    var onFoodSelected: ((FoodEntry) -> Void)?
    
    @State private var showAmountAlert = false
    @State private var ingredientAmount: Double = 100.0
    @State private var pendingIngredient: (name: String, cal: Double, pro: Double, carb: Double, fat: Double)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(foods) { food in
                Button(action: {
                    if onIngredientSelected != nil {
                        pendingIngredient = (food.name, food.caloriesPer100g, food.proteinPer100g, food.carbsPer100g, food.fatPer100g)
                        ingredientAmount = 100.0
                        showAmountAlert = true
                    } else {
                        let tempEntry = FoodEntry(name: food.name, barcode: food.barcode, calories: food.caloriesPer100g, proteinGrams: food.proteinPer100g, carbsGrams: food.carbsPer100g, fatGrams: food.fatPer100g)
                        tempEntry.amountGrams = 100
                        onFoodSelected?(tempEntry)
                        dismiss()
                    }
                }) {
                    VStack(alignment: .leading) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(food.caloriesPer100g, specifier: "%.0f") kcal / 100g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Gespeicherte Lebensmittel")
        .alert("Menge angeben", isPresented: $showAmountAlert) {
            TextField("g/ml", value: $ingredientAmount, format: .number)
                .keyboardType(.decimalPad)
            Button("Abbrechen", role: .cancel) { }
            Button("Hinzufügen") {
                if let pending = pendingIngredient, let onSelected = onIngredientSelected {
                    onSelected(pending.name, pending.cal, pending.pro, pending.carb, pending.fat, ingredientAmount)
                    dismiss()
                }
            }
        } message: {
            Text("Wie viel \(pendingIngredient?.name ?? "davon") möchtest du verwenden?")
        }
    }
}
