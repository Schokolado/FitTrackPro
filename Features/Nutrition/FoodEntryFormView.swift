import SwiftUI
import SwiftData

struct FoodEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allDailyLogs: [DailyLog]
    
    @State var mealType: MealType?
    var prefilledProduct: OFFProduct?
    var prefilledEntry: FoodEntry?
    var targetDate: Date = Date()
    var onSave: ((String) -> Void)? = nil
    
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.healthKitAutoSync) private var healthKitAutoSync = true
    
    @State private var showingValidationError = false
    @State private var showingScanner = false
    
    @State private var name: String = ""
    @State private var barcode: String? = nil
    @State private var amountGrams: Double = 100.0
    
    @State private var caloriesPer100g: Double = 0.0
    @State private var proteinPer100g: Double = 0.0
    @State private var carbsPer100g: Double = 0.0
    @State private var fatPer100g: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        showingScanner = true
                    }) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.brand)
                            Text("Aus Datenbank scannen")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    Picker("Mahlzeit", selection: $mealType) {
                        Text("Bitte wählen").tag(MealType?.none)
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(MealType?.some(type))
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
            .alert("Fehlende Angabe", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte wähle eine Mahlzeit aus (z.B. Frühstück).")
            }
            .sheet(isPresented: $showingScanner) {
                ZStack {
                    BarcodeScannerView(onProductFound: { product in
                        showingScanner = false
                        if let p = product { applyProduct(p) }
                    })
                    
                    #if targetEnvironment(simulator)
                    VStack {
                        Spacer()
                        Button(action: {
                            Task {
                                let service = FoodAPIService()
                                let product = try? await service.fetchProduct(barcode: "5449000000996")
                                DispatchQueue.main.async {
                                    showingScanner = false
                                    if let p = product { applyProduct(p) }
                                }
                            }
                        }) {
                            Text("Simulator Mock Scan")
                                .font(.headline)
                                .padding()
                                .background(Color.brand)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.bottom, 40)
                    }
                    #endif
                }
            }
            .onAppear {
                if let product = prefilledProduct {
                    applyProduct(product)
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
    
    private func applyProduct(_ product: OFFProduct) {
        name = product.productName ?? ""
        barcode = product.code
        if let sq = product.servingQuantity, sq > 0 {
            amountGrams = sq
        } else {
            amountGrams = 100.0
        }
        if let nuts = product.nutriments {
            caloriesPer100g = nuts.energyKcal100g ?? 0.0
            proteinPer100g = nuts.proteins100g ?? 0.0
            carbsPer100g = nuts.carbohydrates100g ?? 0.0
            fatPer100g = nuts.fat100g ?? 0.0
        }
    }
    
    private var ratio: Double { amountGrams / 100.0 }
    private var calculatedCalories: Double { caloriesPer100g * ratio }
    private var calculatedProtein: Double { proteinPer100g * ratio }
    private var calculatedCarbs: Double { carbsPer100g * ratio }
    private var calculatedFat: Double { fatPer100g * ratio }
    
    private func saveEntry() {
        guard let selectedMealType = mealType else {
            showingValidationError = true
            return
        }
        
        let dateString = targetDate.iso8601String()
        let todayLog = allDailyLogs.first(where: { $0.dateString == dateString }) ?? {
            let newLog = DailyLog(dateString: dateString)
            modelContext.insert(newLog)
            return newLog
        }()
        
        let newEntry = FoodEntry(
            name: name,
            timestamp: targetDate,
            mealType: selectedMealType,
            amountGrams: amountGrams,
            calories: calculatedCalories,
            proteinGrams: calculatedProtein,
            carbsGrams: calculatedCarbs,
            fatGrams: calculatedFat,
            dailyLog: todayLog
        )
        
        modelContext.insert(newEntry)
        
        // Auto-save to Eigene Lebensmittel
        let fetchDescriptor = FetchDescriptor<SavedFood>()
        let savedFoods = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let exists = savedFoods.contains { $0.name.lowercased() == name.lowercased() }
        
        if !exists {
            let newSavedFood = SavedFood(
                name: name,
                barcode: barcode,
                caloriesPer100g: caloriesPer100g,
                proteinPer100g: proteinPer100g,
                carbsPer100g: carbsPer100g,
                fatPer100g: fatPer100g
            )
            modelContext.insert(newSavedFood)
        }
        
        if healthKitEnabled && healthKitAutoSync {
            Task { @MainActor in
                do {
                    try await HealthKitService.shared.exportNutrition(entry: newEntry)
                    newEntry.syncedToHealthKit = true
                } catch {
                    print("Nutrition sync failed: \(error)")
                }
            }
        }
        
        if let onSave = onSave {
            onSave(newEntry.name)
        } else {
            dismiss()
        }
    }
}
