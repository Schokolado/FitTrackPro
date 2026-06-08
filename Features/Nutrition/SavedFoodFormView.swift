import SwiftUI
import SwiftData

struct SavedFoodFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var foodToEdit: SavedFood?
    
    @State private var name: String = ""
    @State private var barcode: String = ""
    @State private var calories: Double? = nil
    @State private var protein: Double? = nil
    @State private var carbs: Double? = nil
    @State private var fat: Double? = nil
    
    @State private var showingScanner = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Allgemein")) {
                    TextField("Name (z.B. Vollkornbrot)", text: $name)
                    HStack {
                        TextField("Barcode (optional)", text: $barcode)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            showingScanner = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
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
                        if let food = foodToEdit {
                            food.name = name
                            food.barcode = barcode.isEmpty ? nil : barcode
                            food.caloriesPer100g = calories ?? 0
                            food.proteinPer100g = protein ?? 0
                            food.carbsPer100g = carbs ?? 0
                            food.fatPer100g = fat ?? 0
                        } else {
                            let newFood = SavedFood(
                                name: name,
                                barcode: barcode.isEmpty ? nil : barcode,
                                caloriesPer100g: calories ?? 0,
                                proteinPer100g: protein ?? 0,
                                carbsPer100g: carbs ?? 0,
                                fatPer100g: fat ?? 0
                            )
                            modelContext.insert(newFood)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(onProductFound: { product in
                    showingScanner = false
                    if let product = product {
                        barcode = product.code ?? ""
                        if name.isEmpty { name = product.productName ?? "" }
                        if (calories ?? 0) == 0 { calories = product.nutriments?.energyKcal100g ?? 0 }
                        if (protein ?? 0) == 0 { protein = product.nutriments?.proteins100g ?? 0 }
                        if (carbs ?? 0) == 0 { carbs = product.nutriments?.carbohydrates100g ?? 0 }
                        if (fat ?? 0) == 0 { fat = product.nutriments?.fat100g ?? 0 }
                    }
                })
            }
            .onAppear {
                if let food = foodToEdit {
                    name = food.name
                    barcode = food.barcode ?? ""
                    calories = food.caloriesPer100g
                    protein = food.proteinPer100g
                    carbs = food.carbsPer100g
                    fat = food.fatPer100g
                }
            }
        }
    }
}
