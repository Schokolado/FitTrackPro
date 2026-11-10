import SwiftUI
import SwiftData

struct FoodEntryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allDailyLogs: [DailyLog]
    
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.healthKitAutoSync) private var healthKitAutoSync = true
    
    let entry: FoodEntry
    
    @State private var name: String
    @State private var mealType: MealType
    @State private var selectedDate: Date
    @State private var amountGrams: Double
    
    @State private var calories: Double
    @State private var proteinGrams: Double
    @State private var carbsGrams: Double
    @State private var fatGrams: Double
    
    // Per-gram ratios for automatic scaling when amount changes
    @State private var calPerGram: Double
    @State private var proPerGram: Double
    @State private var carbPerGram: Double
    @State private var fatPerGram: Double
    @State private var isScaling: Bool = false
    
    init(entry: FoodEntry) {
        self.entry = entry
        self._name = State(initialValue: entry.name)
        self._mealType = State(initialValue: entry.mealType)
        self._selectedDate = State(initialValue: entry.timestamp)
        
        let initialAmount = entry.amountGrams > 0 ? entry.amountGrams : 100.0
        self._amountGrams = State(initialValue: initialAmount)
        self._calories = State(initialValue: entry.calories)
        self._proteinGrams = State(initialValue: entry.proteinGrams)
        self._carbsGrams = State(initialValue: entry.carbsGrams)
        self._fatGrams = State(initialValue: entry.fatGrams)
        
        self._calPerGram = State(initialValue: entry.calories / initialAmount)
        self._proPerGram = State(initialValue: entry.proteinGrams / initialAmount)
        self._carbPerGram = State(initialValue: entry.carbsGrams / initialAmount)
        self._fatPerGram = State(initialValue: entry.fatGrams / initialAmount)
    }
    
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
                    
                    DatePicker("Datum", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Menge (g/ml)")
                        Spacer()
                        TextField("g/ml", value: $amountGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Stepper("", value: $amountGrams, in: 1...5000, step: 10)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("Nährwerte (für \(Int(amountGrams))g/ml)")) {
                    HStack {
                        Text("Kalorien (kcal)")
                        Spacer()
                        TextField("kcal", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("g", value: $proteinGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Kohlenhydrate (g)")
                        Spacer()
                        TextField("g", value: $carbsGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fett (g)")
                        Spacer()
                        TextField("g", value: $fatGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amountGrams <= 0)
                }
            }
            .onChange(of: amountGrams) { _, newAmount in
                guard !isScaling, newAmount > 0 else { return }
                isScaling = true
                calories = roundMacro(calPerGram * newAmount)
                proteinGrams = roundMacro(proPerGram * newAmount)
                carbsGrams = roundMacro(carbPerGram * newAmount)
                fatGrams = roundMacro(fatPerGram * newAmount)
                isScaling = false
            }
            .onChange(of: calories) { _, newCal in
                guard !isScaling, amountGrams > 0 else { return }
                calPerGram = newCal / amountGrams
            }
            .onChange(of: proteinGrams) { _, newPro in
                guard !isScaling, amountGrams > 0 else { return }
                proPerGram = newPro / amountGrams
            }
            .onChange(of: carbsGrams) { _, newCarb in
                guard !isScaling, amountGrams > 0 else { return }
                carbPerGram = newCarb / amountGrams
            }
            .onChange(of: fatGrams) { _, newFat in
                guard !isScaling, amountGrams > 0 else { return }
                fatPerGram = newFat / amountGrams
            }
        }
    }
    
    private func roundMacro(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
    
    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.name = trimmedName
        entry.mealType = mealType
        entry.amountGrams = amountGrams
        entry.calories = calories
        entry.proteinGrams = proteinGrams
        entry.carbsGrams = carbsGrams
        entry.fatGrams = fatGrams
        entry.timestamp = selectedDate
        
        let newDateString = selectedDate.iso8601String()
        if entry.dailyLog?.dateString != newDateString {
            let targetLog = allDailyLogs.first(where: { $0.dateString == newDateString }) ?? {
                let newLog = DailyLog(dateString: newDateString)
                modelContext.insert(newLog)
                return newLog
            }()
            entry.dailyLog = targetLog
        }
        
        try? modelContext.save()
        
        if healthKitEnabled && healthKitAutoSync {
            Task { @MainActor in
                do {
                    try await HealthKitService.shared.updateNutrition(entry: entry)
                    entry.syncedToHealthKit = true
                } catch {
                    print("Failed to sync updated nutrition: \(error)")
                }
            }
        }
        
        dismiss()
    }
}
