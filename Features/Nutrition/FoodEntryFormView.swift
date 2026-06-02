import SwiftUI
import SwiftData

struct FoodEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allDailyLogs: [DailyLog]
    
    @State var mealType: MealType
    var prefilledProduct: OFFProduct?
    var prefilledEntry: FoodEntry?
    var onSave: ((String) -> Void)? = nil
    
    @State private var name: String = ""
    @State private var amountGrams: Double = 100.0
    
    @State private var caloriesPer100g: Double = 0.0
    @State private var proteinPer100g: Double = 0.0
    @State private var carbsPer100g: Double = 0.0
    @State private var fatPer100g: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    Picker("Mahlzeit", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    HStack {
                        Text("Menge (g/ml)")
                        Spacer()
                        TextField("g/ml", value: $amountGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Stepper("", value: $amountGrams, in: 0...5000, step: 10)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("Nährwerte (pro 100g/ml)")) {
                    HStack {
                        Text("Kalorien (kcal)")
                        Spacer()
                        TextField("kcal", value: $caloriesPer100g, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("g", value: $proteinPer100g, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Kohlenhydrate (g)")
                        Spacer()
                        TextField("g", value: $carbsPer100g, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fett (g)")
                        Spacer()
                        TextField("g", value: $fatPer100g, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Berechnet (für \(Int(amountGrams))g/ml)")) {
                    HStack {
                        Text("Kalorien")
                        Spacer()
                        Text("\(Int(calculatedCalories)) kcal")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(String(format: "%.1f", calculatedProtein)) g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Kohlenhydrate")
                        Spacer()
                        Text("\(String(format: "%.1f", calculatedCarbs)) g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Fett")
                        Spacer()
                        Text("\(String(format: "%.1f", calculatedFat)) g")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Eintrag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveEntry()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let product = prefilledProduct {
                    name = product.productName ?? ""
                    if let nuts = product.nutriments {
                        caloriesPer100g = nuts.energyKcal100g ?? 0.0
                        proteinPer100g = nuts.proteins100g ?? 0.0
                        carbsPer100g = nuts.carbohydrates100g ?? 0.0
                        fatPer100g = nuts.fat100g ?? 0.0
                    }
                } else if let entry = prefilledEntry {
                    name = entry.name
                    amountGrams = entry.amountGrams > 0 ? entry.amountGrams : 100.0
                    
                    // Reverse calculate per 100g from the entry's totals
                    let ratio = amountGrams / 100.0
                    if ratio > 0 {
                        caloriesPer100g = entry.calories / ratio
                        proteinPer100g = entry.proteinGrams / ratio
                        carbsPer100g = entry.carbsGrams / ratio
                        fatPer100g = entry.fatGrams / ratio
                    }
                }
            }
        }
    }
    
    private var ratio: Double { amountGrams / 100.0 }
    private var calculatedCalories: Double { caloriesPer100g * ratio }
    private var calculatedProtein: Double { proteinPer100g * ratio }
    private var calculatedCarbs: Double { carbsPer100g * ratio }
    private var calculatedFat: Double { fatPer100g * ratio }
    
    private func saveEntry() {
        let dateString = Date().iso8601String()
        let todayLog = allDailyLogs.first(where: { $0.dateString == dateString }) ?? {
            let newLog = DailyLog(dateString: dateString)
            modelContext.insert(newLog)
            return newLog
        }()
        
        let newEntry = FoodEntry(
            name: name,
            timestamp: Date(),
            mealType: mealType,
            amountGrams: amountGrams,
            calories: calculatedCalories,
            proteinGrams: calculatedProtein,
            carbsGrams: calculatedCarbs,
            fatGrams: calculatedFat,
            dailyLog: todayLog
        )
        
        modelContext.insert(newEntry)
        
        if let onSave = onSave {
            onSave(newEntry.name)
        } else {
            dismiss()
        }
    }
}
