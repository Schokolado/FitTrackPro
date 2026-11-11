import SwiftUI
import SwiftData

struct NutritionDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(\.miniPlayerBottomInset) private var miniPlayerBottomInset
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allDailyLogs: [DailyLog]
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var allWorkouts: [WorkoutSession]
    
    @State private var selectedDate: Date = Date()
    @State private var activeBurnedCalories: Double? = nil
    @State private var showingAddEntry = false
    @State private var showingCalorieDetails = false
    @State private var showingFoodSearch = false
    @State private var showingScanner = false
    @State private var selectedMealType: MealType? = nil
    @State private var scannedProduct: OFFProduct? = nil
    
    @State private var showingSavedAlert = false
    @State private var savedFoodName = ""
    @State private var showingDatePicker = false
    
    @AppStorage("dailyCalorieGoal") private var goalCalories: Double = 2500
    @AppStorage(AppStorageKeys.addActiveCaloriesToGoal) private var addActiveCaloriesToGoal: Bool = true
    @AppStorage(AppStorageKeys.nutritionTolerance) private var nutritionTolerance: Double = 300
    @AppStorage(AppStorageKeys.calorieWarningEveningHour) private var calorieWarningEveningHour: Int = 18
    @AppStorage("nutritionGoalProtein") private var goalProtein: Double = 150
    @AppStorage("nutritionGoalCarbs") private var goalCarbs: Double = 250
    @AppStorage("nutritionGoalFat") private var goalFat: Double = 70
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.userBirthDate) private var birthDateInterval: Double = 0
    @AppStorage(AppStorageKeys.userBiologicalSex) private var userSex: String = "other"
    @AppStorage(AppStorageKeys.userHeightCm) private var heightCm: Double = 175
    @AppStorage(AppStorageKeys.onboardingWeightKg) private var onboardingWeightKg: Double = 0
    
    private var todayLog: DailyLog? {
        let dateString = selectedDate.iso8601String()
        return allDailyLogs.first { $0.dateString == dateString }
    }
    
    private var todayEntries: [FoodEntry] {
        todayLog?.foodEntries ?? []
    }
    
    @State private var navId = UUID()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    WeekCalendarView(
                        selectedDate: $selectedDate,
                        allDailyLogs: allDailyLogs,
                        goalCalories: goalCalories,
                        tolerance: nutritionTolerance
                    )
                    
                    macroSummarySection
                    
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        mealSection(for: mealType)
                    }
                }
                .padding()
                .padding(.bottom, 100) // Platz für FAB
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Ernährung")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(destination: FoodManagementView()) {
                        Image(systemName: "list.bullet.clipboard")
                    }
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                FoodEntryFormView(mealType: selectedMealType, prefilledProduct: scannedProduct, targetDate: selectedDate) { savedName in
                    showingAddEntry = false
                    savedFoodName = savedName
                    showingSavedAlert = true
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingCalorieDetails) {
                let consumed = todayEntries.reduce(0) { $0 + $1.calories }
                let active = EnergyCalculator.totalActiveCalories(
                    healthKitActive: activeBurnedCalories,
                    sessions: allWorkouts,
                    on: selectedDate
                )
                let weight = weightEntries.first?.weightKg ?? (onboardingWeightKg > 0 ? onboardingWeightKg : nil)
                let bmr = EnergyCalculator.estimatedBMR(
                    weightKg: weight,
                    heightCm: heightCm,
                    birthDateTimestamp: birthDateInterval,
                    biologicalSex: userSex,
                    referenceDate: selectedDate
                )
                CalorieBreakdownSheet(
                    date: selectedDate,
                    consumed: consumed,
                    baseGoal: goalCalories,
                    activeBurned: active,
                    addActiveToGoal: addActiveCaloriesToGoal,
                    bmr: bmr,
                    tolerance: nutritionTolerance,
                    eveningHour: calorieWarningEveningHour
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(mealType: selectedMealType, targetDate: selectedDate) { savedName in
                    showingFoodSearch = false
                    savedFoodName = savedName
                    showingSavedAlert = true
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingScanner) {
                ZStack {
                    BarcodeScannerView(onProductFound: { product in
                        showingScanner = false
                        scannedProduct = product
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingAddEntry = true
                        }
                    })
                    
                    #if targetEnvironment(simulator)
                    VStack {
                        Spacer()
                        Button(action: {
                            Task {
                                let service = FoodAPIService()
                                // Beispiel-Barcode für den Simulator (Coca Cola oder ein bekannter Artikel)
                                let product = try? await service.fetchProduct(barcode: "5449000000996")
                                DispatchQueue.main.async {
                                    showingScanner = false
                                    scannedProduct = product
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showingAddEntry = true
                                    }
                                }
                            }
                        }) {
                            Text("Simulator Mock Scan (Coca Cola)")
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
                ensureDailyLogExists()
            }
            .onChange(of: selectedDate) { _, _ in
                ensureDailyLogExists()
            }
            .task(id: selectedDate) {
                await refreshActiveCalories(for: selectedDate)
            }
            .onChange(of: healthKitEnabled) { _, enabled in
                if enabled {
                    Task { await refreshActiveCalories(for: selectedDate) }
                } else {
                    activeBurnedCalories = nil
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshActiveCalories(for: selectedDate) }
                }
            }
            .alert("Gespeichert", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(savedFoodName) wurde hinzugefügt.")
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: {
                    selectedMealType = nil
                    showingFoodSearch = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Mahlzeit")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                .padding()
                .padding(.bottom, 20 + miniPlayerBottomInset)
            }
        }
        .id(navId)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 2 {
                navId = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetNutritionToToday"))) { _ in
            selectedDate = Date()
            navId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNutritionAddEntry"))) { _ in
            selectedDate = Date()
            selectedMealType = nil
            showingFoodSearch = true
        }
    }
    
    // The datePickerSection has been replaced by WeekCalendarView.
    
    private var macroSummarySection: some View {
        VStack(spacing: Spacing.md) {
            let totalCals = todayEntries.reduce(0) { $0 + $1.calories }
            let totalProtein = todayEntries.reduce(0) { $0 + $1.proteinGrams }
            let totalCarbs = todayEntries.reduce(0) { $0 + $1.carbsGrams }
            let totalFat = todayEntries.reduce(0) { $0 + $1.fatGrams }
            let activeBurned = EnergyCalculator.totalActiveCalories(
                healthKitActive: activeBurnedCalories,
                sessions: allWorkouts,
                on: selectedDate
            )
            let effectiveGoal = goalCalories + (addActiveCaloriesToGoal ? (activeBurned ?? 0) : 0)
            let ringState = CalorieRingEvaluator.evaluate(
                consumed: totalCals,
                goal: effectiveGoal,
                tolerance: nutritionTolerance,
                date: selectedDate,
                eveningHour: calorieWarningEveningHour
            )
            
            Text("Kalorien")
                .font(.headline)
            
            Button {
                showingCalorieDetails = true
            } label: {
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .stroke(ringState.color.opacity(0.25), lineWidth: 15)
                        Circle()
                            .trim(from: 0, to: min(CGFloat(totalCals / max(effectiveGoal, 1)), 1.0))
                            .stroke(ringState.color, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalCals)
                        
                        VStack(spacing: 2) {
                            Text("\(Int(totalCals))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("/ \(Int(effectiveGoal)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 150)
                    .padding(.vertical, Spacing.sm)

                    HStack(spacing: 6) {
                        if ringState == .surplusWarning {
                            Text("+\(Int(totalCals - effectiveGoal)) kcal über Ziel")
                                .foregroundColor(.destructive)
                                .fontWeight(.semibold)
                        } else if ringState == .eveningDeficitWarning {
                            Text("−\(Int(effectiveGoal - totalCals)) kcal unter Ziel")
                                .foregroundColor(.warning)
                                .fontWeight(.semibold)
                        } else if totalCals > effectiveGoal {
                            Text("+\(Int(totalCals - effectiveGoal)) kcal über Ziel")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Noch \(Int(max(effectiveGoal - totalCals, 0))) kcal offen")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let active = activeBurned {
                Button {
                    showingCalorieDetails = true
                } label: {
                    energyExpenditureStrip(consumed: totalCals, activeBurned: active)
                }
                .buttonStyle(.plain)
            }
            
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

    @ViewBuilder
    private func energyExpenditureStrip(consumed: Double, activeBurned: Double) -> some View {
        let weight = weightEntries.first?.weightKg ?? (onboardingWeightKg > 0 ? onboardingWeightKg : nil)
        let bmr = EnergyCalculator.estimatedBMR(
            weightKg: weight,
            heightCm: heightCm,
            birthDateTimestamp: birthDateInterval,
            biologicalSex: userSex,
            referenceDate: selectedDate
        )
        let totalBurned = bmr.map { $0 + activeBurned }
        let referenceForBalance = totalBurned ?? (goalCalories + activeBurned)
        let balance = Int((consumed - referenceForBalance).rounded())
        let balancePrefix = balance > 0 ? "+" : ""

        HStack(spacing: 10) {
            energyMetricTile(
                title: "Aktiv verbrannt",
                value: "\(Int(activeBurned)) kcal",
                icon: "flame.fill",
                tint: .orange
            )

            if let totalBurned {
                energyMetricTile(
                    title: "Tagesumsatz",
                    value: "\(Int(totalBurned)) kcal",
                    icon: "bolt.fill",
                    tint: .brand
                )
            }

            energyMetricTile(
                title: totalBurned != nil ? "vs. Umsatz" : "vs. Ziel",
                value: "\(balancePrefix)\(balance) kcal",
                icon: balance <= 0 ? "arrow.down.right" : "arrow.up.right",
                tint: balance <= 0 ? .green : .orange
            )
        }
    }

    private func energyMetricTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.backgroundPrimary.opacity(0.75))
        .cornerRadius(10)
    }

    private func refreshActiveCalories(for date: Date) async {
        guard healthKitEnabled else {
            await MainActor.run { activeBurnedCalories = nil }
            return
        }
        let calendar = Calendar.current
        if calendar.startOfDay(for: date) > calendar.startOfDay(for: Date()) {
            await MainActor.run { activeBurnedCalories = nil }
            return
        }
        let cals = try? await HealthKitService.shared.fetchActiveEnergyBurned(for: date)
        await MainActor.run {
            activeBurnedCalories = cals
        }
    }
}

extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
// WeekCalendarView added below
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let allDailyLogs: [DailyLog]
    let goalCalories: Double
    let tolerance: Double
    @State private var showingDatePicker = false
    
    // Berechnet die 7 Tage der Woche (Mo-So), in der sich das selectedDate befindet.
    var weekDates: [Date] {
        var dates: [Date] = []
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 2 = Montag
        
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                dates.append(date)
            }
        }
        return dates
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Monat/Jahr und unsichtbarer Button für DatePicker beim Klick auf den Text
            HStack {
                Button(action: { showingDatePicker = true }) {
                    HStack(spacing: 4) {
                        Text(monthYearString(for: selectedDate))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { withAnimation { selectedDate = Date() } }) {
                    Text("Heute")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.brand)
                }
            }
            .padding(.horizontal)
            .popover(isPresented: $showingDatePicker) {
                DatePicker("Datum wählen", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .frame(width: 320, height: 340)
                    .presentationCompactAdaptation(.popover)
                    .onChange(of: selectedDate) { _, _ in
                        showingDatePicker = false
                    }
            }
            
            // Wochentage Leiste
            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                    let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
                    
                    let log = allDailyLogs.first(where: { $0.dateString == date.iso8601String() })
                    let totalCals: Double = log?.foodEntries?.reduce(0.0) { $0 + $1.calories } ?? 0.0
                    
                    let dotColor: Color = {
                        guard isPast else { return .clear }
                        if totalCals == 0 { return .red }
                        if abs(totalCals - goalCalories) <= tolerance { return .green }
                        return .orange
                    }()
                    
                    VStack(spacing: 2) {
                        Text(dayOfWeek(for: date))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : (isToday ? .brand : .secondary))
                            .padding(.bottom, 2)
                        
                        Text(dayOfMonth(for: date))
                            .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Circle()
                            .fill(dotColor)
                            .frame(width: 4, height: 4)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.brand : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 16)
        .cardStyle()
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // Mo, Di, Mi...
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func dayOfMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
        WeekCalendarView(selectedDate: .constant(Date()), allDailyLogs: [], goalCalories: 2500, tolerance: 300)
            .padding()
    }
}

private struct CalorieBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let consumed: Double
    let baseGoal: Double
    let activeBurned: Double?
    let addActiveToGoal: Bool
    let bmr: Double?
    let tolerance: Double
    let eveningHour: Int

    private var activeValue: Double { activeBurned ?? 0 }
    private var effectiveGoal: Double { baseGoal + (addActiveToGoal ? activeValue : 0) }
    private var totalBurned: Double? { bmr.map { $0 + activeValue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    goalCard
                    expenditureCard
                }
                .padding()
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Kalorien-Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var goalCard: some View {
        let remaining = effectiveGoal - consumed
        let ringState = CalorieRingEvaluator.evaluate(
            consumed: consumed,
            goal: effectiveGoal,
            tolerance: tolerance,
            date: date,
            eveningHour: eveningHour
        )

        return VStack(alignment: .leading, spacing: 12) {
            Label("Tagesziel & Budget", systemImage: "target")
                .font(.headline)

            breakdownRow(title: "Basis-Kalorienziel", value: "\(Int(baseGoal)) kcal")
            breakdownRow(
                title: addActiveToGoal ? "+ Aktiv verbrannt (addiert)" : "Aktiv verbrannt (nicht addiert)",
                value: activeBurned != nil ? (addActiveToGoal ? "+\(Int(activeValue)) kcal" : "\(Int(activeValue)) kcal") : "–",
                valueColor: addActiveToGoal ? .orange : .secondary
            )
            Divider()
            breakdownRow(title: "Effektives Tagesziel", value: "\(Int(effectiveGoal)) kcal", bold: true)
            breakdownRow(title: "Bereits getrackt", value: "\(Int(consumed)) kcal")
            breakdownRow(
                title: remaining >= 0 ? "Noch offen" : "Über Ziel",
                value: remaining >= 0 ? "\(Int(remaining)) kcal" : "+\(Int(-remaining)) kcal",
                valueColor: ringState.color,
                bold: true
            )

            Text("Toleranz: ±\(Int(max(tolerance, 0))) kcal (ab \(eveningHour):00 Uhr orange bei Defizit, rot bei Überschuss).")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .cardStyle()
    }

    private var expenditureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Energieverbrauch & Bilanz", systemImage: "flame.fill")
                .font(.headline)

            if let bmr {
                let total = bmr + activeValue
                let diff = Int((consumed - total).rounded())
                let prefix = diff > 0 ? "+" : ""

                breakdownRow(title: "Grundumsatz (24h, geschätzt)", value: "\(Int(bmr)) kcal")
                breakdownRow(title: "+ Aktiv verbrannt (bisher)", value: "+\(Int(activeValue)) kcal", valueColor: .orange)
                Divider()
                breakdownRow(title: "Tagesumsatz gesamt", value: "\(Int(total)) kcal", bold: true)
                breakdownRow(title: "Gegessen (bisher)", value: "\(Int(consumed)) kcal")
                breakdownRow(
                    title: diff <= 0 ? "Kaloriendefizit vs. Umsatz" : "Kalorienüberschuss vs. Umsatz",
                    value: "\(prefix)\(diff) kcal",
                    valueColor: diff <= 0 ? .green : .orange,
                    bold: true
                )

                Text("Vergleicht deine bisher getrackten Kalorien mit deinem vollen Tagesumsatz (24h-Grundumsatz + bisherige Aktivitätskalorien).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                breakdownRow(title: "Aktiv verbrannt (bisher)", value: "\(Int(activeValue)) kcal", valueColor: .orange)
                Text("Hinterlege dein Körpergewicht, um deinen geschätzten 24h-Grundumsatz und die Gesamtbilanz zu berechnen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .cardStyle()
    }

    private func breakdownRow(
        title: String,
        value: String,
        valueColor: Color = .primary,
        bold: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundColor(valueColor)
        }
    }
}
