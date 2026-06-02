import SwiftUI
import SwiftData

struct NutritionDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var selectedDate: Date = Date()
    @State private var showingAddEntry = false
    @State private var showingScanner = false
    @State private var selectedMealType: MealType = .breakfast
    @State private var scannedProduct: OFFProduct? = nil
    
    @State private var showingSavedAlert = false
    @State private var savedFoodName = ""
    
    @AppStorage("nutritionGoalCalories") private var goalCalories: Double = 2000
    @AppStorage("nutritionGoalProtein") private var goalProtein: Double = 150
    @AppStorage("nutritionGoalCarbs") private var goalCarbs: Double = 250
    @AppStorage("nutritionGoalFat") private var goalFat: Double = 70
    
    private var todayLog: DailyLog? {
        let dateString = selectedDate.iso8601String()
        return allDailyLogs.first { $0.dateString == dateString }
    }
    
    private var todayEntries: [FoodEntry] {
        todayLog?.foodEntries ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    datePickerSection
                    
                    macroSummarySection
                    
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        mealSection(for: mealType)
                    }
                }
                .padding()
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Ernährung")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                FoodEntryFormView(mealType: selectedMealType, prefilledProduct: scannedProduct) { savedName in
                    showingAddEntry = false
                    savedFoodName = savedName
                    showingSavedAlert = true
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(onProductFound: { product in
                    showingScanner = false
                    scannedProduct = product
                    showingAddEntry = true
                })
            }
            .onAppear {
                ensureDailyLogExists()
            }
            .onChange(of: selectedDate) { _, _ in
                ensureDailyLogExists()
            }
            .alert("Gespeichert", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(savedFoodName) wurde hinzugefügt.")
            }
        }
    }
    
    private var datePickerSection: some View {
        DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .padding()
            .cardStyle()
    }
    
    private var macroSummarySection: some View {
        VStack(spacing: Spacing.md) {
            let totalCals = todayEntries.reduce(0) { $0 + $1.calories }
            let totalProtein = todayEntries.reduce(0) { $0 + $1.proteinGrams }
            let totalCarbs = todayEntries.reduce(0) { $0 + $1.carbsGrams }
            let totalFat = todayEntries.reduce(0) { $0 + $1.fatGrams }
            
            Text("Kalorien")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.brandSecondary.opacity(0.3), lineWidth: 15)
                Circle()
                    .trim(from: 0, to: min(CGFloat(totalCals / goalCalories), 1.0))
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(totalCals))")
                        .font(.system(size: 32, weight: .bold))
                    Text("/ \(Int(goalCalories)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 150)
            .padding(.vertical, Spacing.sm)
            
            HStack(spacing: Spacing.lg) {
                macroBar(title: "Protein", current: totalProtein, goal: goalProtein, color: .blue)
                macroBar(title: "Kohlenhydrate", current: totalCarbs, goal: goalCarbs, color: .orange)
                macroBar(title: "Fett", current: totalFat, goal: goalFat, color: .red)
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func macroBar(title: String, current: Double, goal: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: min(geometry.size.width * CGFloat(current / goal), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(current)) / \(Int(goal)) g")
                .font(.caption2)
        }
    }
    
    private func mealSection(for type: MealType) -> some View {
        let entries = todayEntries.filter { $0.mealType == type }
        let totalCals = entries.reduce(0) { $0 + $1.calories }
        let dateString = selectedDate.iso8601String()
        
        return NavigationLink(destination: MealDetailView(mealType: type, dateString: dateString)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(entries.count) Einträge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(totalCals)) kcal")
                    .font(.headline)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
    
    private func ensureDailyLogExists() {
        let dateString = selectedDate.iso8601String()
        if !allDailyLogs.contains(where: { $0.dateString == dateString }) {
            let newLog = DailyLog(dateString: dateString)
            modelContext.insert(newLog)
        }
    }
    
    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
    }
}

extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: self)
    }
}
