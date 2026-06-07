import SwiftUI
import SwiftData

struct NutritionDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutManager.self) private var workoutManager
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var selectedDate: Date = Date()
    @State private var showingAddEntry = false
    @State private var showingFoodSearch = false
    @State private var showingScanner = false
    @State private var selectedMealType: MealType? = nil
    @State private var scannedProduct: OFFProduct? = nil
    
    @State private var showingSavedAlert = false
    @State private var savedFoodName = ""
    @State private var showingDatePicker = false
    
    @AppStorage("dailyCalorieGoal") private var goalCalories: Double = 2500
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
    
    @State private var navId = UUID()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    WeekCalendarView(selectedDate: $selectedDate)
                    
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(mealType: selectedMealType) { savedName in
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
                .padding(.bottom, 20)
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
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
// WeekCalendarView added below
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
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
                    
                    VStack(spacing: 6) {
                        Text(dayOfWeek(for: date))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : (isToday ? .brand : .secondary))
                        
                        Text(dayOfMonth(for: date))
                            .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.brand : Color.clear)
                    .clipShape(Capsule())
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
        WeekCalendarView(selectedDate: .constant(Date()))
            .padding()
    }
}
