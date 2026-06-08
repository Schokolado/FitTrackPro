import SwiftUI
import SwiftData

struct SavedFoodFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var barcode: String = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Allgemein")) {
                    TextField("Name (z.B. Vollkornbrot)", text: $name)
                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Nährwerte pro 100g / Portion")) {
                    HStack {
                        Text("Kalorien")
                        Spacer()
                        TextField("kcal", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("g", value: $protein, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Kohlenhydrate")
                        Spacer()
                        TextField("g", value: $carbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fett")
                        Spacer()
                        TextField("g", value: $fat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Neues Lebensmittel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let newFood = SavedFood(
                            name: name,
                            barcode: barcode.isEmpty ? nil : barcode,
                            caloriesPer100g: calories,
                            proteinPer100g: protein,
                            carbsPer100g: carbs,
                            fatPer100g: fat
                        )
                        modelContext.insert(newFood)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
