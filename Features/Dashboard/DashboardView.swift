import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutManager.self) private var workoutManager
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Double = 2500
    @AppStorage(AppStorageKeys.addActiveCaloriesToGoal) private var addActiveCaloriesToGoal: Bool = true
    @AppStorage(AppStorageKeys.nutritionTolerance) private var nutritionTolerance: Double = 300
    @AppStorage(AppStorageKeys.calorieWarningEveningHour) private var calorieWarningEveningHour: Int = 18
    @AppStorage("daily_step_goal") private var dailyStepGoal: Int = 10000
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.userBirthDate) private var birthDateInterval: Double = 0
    @AppStorage(AppStorageKeys.userBiologicalSex) private var userSex: String = "other"
    @AppStorage(AppStorageKeys.userHeightCm) private var heightCm: Double = 175
    @AppStorage(AppStorageKeys.onboardingWeightKg) private var onboardingWeightKg: Double = 0
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("cached_today_steps") private var cachedTodaySteps: Int = 0
    @AppStorage("cached_today_steps_date") private var cachedTodayStepsDate: String = ""
    
    @State private var todaySteps: Int = 0
    @State private var todayHealthKitActiveCalories: Double? = nil
    @State private var showingStepTrackerFromWidget = false
    
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var allFoodEntries: [FoodEntry]
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    @Query private var manualStepEntries: [StepEntry]
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var waterEntries: [WaterEntry]
    
    var todayFoodEntries: [FoodEntry] {
        let todayString = Date().iso8601String()
        return allFoodEntries.filter { $0.dailyLog?.dateString == todayString }
    }
    
    var todayWorkouts: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.startTime) && $0.endTime != nil }
    }
    
    var lastWorkout: WorkoutSession? {
        let calendar = Calendar.current
        return workouts.first { !calendar.isDateInToday($0.startTime) && $0.endTime != nil }
    }
    
    var totalTodaySteps: Int {
        let todayString = Date().iso8601String()
        let manual = manualStepEntries.filter { $0.dateString == todayString }.reduce(0) { $0 + $1.steps }
        let currentSteps = (cachedTodayStepsDate == todayString) ? todaySteps : 0
        return currentSteps + manual
    }
    
    var consumedCalories: Double {
        todayFoodEntries.reduce(0.0) { $0 + $1.calories }
    }
    
    var consumedCarbs: Double {
        todayFoodEntries.reduce(0.0) { $0 + $1.carbsGrams }
    }
    
    var consumedProtein: Double {
        todayFoodEntries.reduce(0.0) { $0 + $1.proteinGrams }
    }
    
    var consumedFat: Double {
        todayFoodEntries.reduce(0.0) { $0 + $1.fatGrams }
    }

    private var todayActiveCalories: Double? {
        EnergyCalculator.totalActiveCalories(
            healthKitActive: todayHealthKitActiveCalories,
            sessions: workouts,
            on: Date()
        )
    }

    private var effectiveDailyCalorieGoal: Double {
        dailyCalorieGoal + (addActiveCaloriesToGoal ? (todayActiveCalories ?? 0) : 0)
    }

    private var todayEstimatedBMR: Double? {
        let weight = weightEntries.first?.weightKg ?? (onboardingWeightKg > 0 ? onboardingWeightKg : nil)
        return EnergyCalculator.estimatedBMR(
            weightKg: weight,
            heightCm: heightCm,
            birthDateTimestamp: birthDateInterval,
            biologicalSex: userSex
        )
    }

    private var todayTotalBurnedCalories: Double? {
        guard let active = todayActiveCalories, let bmr = todayEstimatedBMR else { return nil }
        return bmr + active
    }
    @State private var navId = UUID()
    @StateObject private var layoutManager = DashboardLayoutManager()
    @State private var isEditMode = false
    @State private var showingCalorieBreakdown = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(greetingMessage)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                
                                if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Willkommen zurück")
                                        .font(.largeTitle.bold())
                                } else {
                                    Text("Willkommen zurück,")
                                        .font(.largeTitle.bold())
                                    Text(userName)
                                        .font(.largeTitle.bold())
                                        .foregroundColor(.brand)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Quick Actions
                        HStack(spacing: 16) {
                            Button(action: {
                                selectedTab = 1 // Training Tab
                                UserDefaults.standard.set(0, forKey: "trainingSelectedTab") // Pläne
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Workout")
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                selectedTab = 2 // Nutrition Tab
                                NotificationCenter.default.post(name: NSNotification.Name("ResetNutritionToToday"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("OpenNutritionAddEntry"), object: nil)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Mahlzeit")
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Dynamic Cards
                        DashboardGridLayout(spacing: 16) {
                            ForEach(layoutManager.cards, id: \.id) { card in
                                renderCardWithEditOverlay(card)
                                    .dashboardCardSize(card.size)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await refreshSteps()
                }
                .scrollContentBackground(.hidden)
                .background(
                    Color.backgroundPrimary.ignoresSafeArea()
                        .onDrop(of: [UTType.plainText], delegate: DashboardResetDropDelegate(layoutManager: layoutManager))
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isEditMode {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                withAnimation { isEditMode = false }
                                layoutManager.draggedItem = nil
                            }) {
                                Text("Fertig")
                            }
                            .fontWeight(.bold)
                        }
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(action: {
                                    isEditMode.toggle()
                                    if !isEditMode {
                                        layoutManager.draggedItem = nil
                                    }
                                }) {
                                    Label("Dashboard anpassen", systemImage: "slider.horizontal.3")
                                }
                                
                                NavigationLink(destination: LazyView(SettingsView())) {
                                    Label("Einstellungen", systemImage: "gearshape.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showingStepTrackerFromWidget) {
                    StepTrackerView()
                }
                .sheet(isPresented: $showingCalorieBreakdown) {
                    CalorieBreakdownSheet(
                        date: Date(),
                        consumed: consumedCalories,
                        baseGoal: dailyCalorieGoal,
                        activeBurned: todayActiveCalories,
                        addActiveToGoal: addActiveCaloriesToGoal,
                        bmr: todayEstimatedBMR,
                        tolerance: nutritionTolerance,
                        eveningHour: calorieWarningEveningHour
                    )
                    .presentationDetents([.medium, .large])
                }
        }
        .id(navId)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenStepTracker"))) { _ in
            showingStepTrackerFromWidget = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 0 {
                navId = UUID()
            }
        }
        .task {
            // Load from cache instantly
            let todayString = Date().iso8601String()
            if cachedTodayStepsDate == todayString {
                todaySteps = cachedTodaySteps
            }
            
            await refreshSteps()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshSteps()
                }
            }
        }
        .onChange(of: healthKitEnabled) { _, newValue in
            if newValue {
                HealthKitService.shared.startStepBackgroundObserver()
                Task {
                    await refreshSteps()
                }
            } else {
                todayHealthKitActiveCalories = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task {
                await refreshSteps()
            }
        }
    }
    
    private func refreshSteps() async {
        if healthKitEnabled {
            if let steps = try? await HealthKitService.shared.fetchSteps() {
                await MainActor.run {
                    self.todaySteps = steps
                    self.cachedTodaySteps = steps
                    self.cachedTodayStepsDate = Date().iso8601String()
                }
            }

            if let activeKcal = try? await HealthKitService.shared.fetchActiveEnergyBurned(for: Date()) {
                await MainActor.run {
                    self.todayHealthKitActiveCalories = activeKcal
                }
            }
            
            let calendar = Calendar.current
            let endDate = Date()
            if let startDate = calendar.date(byAdding: .day, value: -6, to: endDate),
               let history = try? await HealthKitService.shared.fetchStepsHistory(startDate: startDate, endDate: endDate) {
                var cacheDict: [String: Int] = [:]
                for item in history {
                    cacheDict[item.date.iso8601String()] = item.steps
                }
                if let encoded = try? JSONEncoder().encode(cacheDict) {
                    await MainActor.run {
                        UserDefaults.standard.set(encoded, forKey: "weekly_healthkit_steps_cache")
                        WidgetDataSync.sync()
                    }
                    return
                }
            }
            
            await MainActor.run {
                WidgetDataSync.sync()
            }
        }
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Guten Morgen"
        case 12..<18: return "Guten Tag"
        default: return "Guten Abend"
        }
    }
    
    // MARK: - Dynamic Rendering
    
    @ViewBuilder
    private func renderCardWithEditOverlay(_ card: DashboardCardConfig) -> some View {
        let baseContent = renderCard(card)
            .contentShape(Rectangle())
            .jiggle(isEnabled: isEditMode)
        
        if isEditMode {
            baseContent
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 24, style: .continuous))
                .opacity(layoutManager.draggedItem == card.type ? 0.001 : 1.0)
                .overlay(alignment: .topTrailing) {
                    if layoutManager.draggedItem == nil {
                        Button {
                            withAnimation { layoutManager.toggleSize(for: card.type) }
                        } label: {
                            Image(systemName: card.size == .large ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.up.left.and.arrow.down.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white, .gray.opacity(0.8))
                                .background(Circle().fill(Color.black.opacity(0.3)))
                        }
                        .padding(-8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onDrag {
                    if !isEditMode { return NSItemProvider() }
                    layoutManager.hoveredArea = card.type.rawValue
                    layoutManager.draggedItem = card.type
                    let provider = TrackingItemProvider(object: card.type.rawValue as NSString)
                    provider.deinitAction = {
                        layoutManager.draggedItem = nil
                        layoutManager.save()
                    }
                    return provider
                } preview: {
                    let screenWidth = UIScreen.main.bounds.width - 32
                    renderCardContent(card)
                        .frame(width: card.size == .large ? screenWidth : (screenWidth - 16) / 2)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .environment(\.modelContext, modelContext)
                }
                .onDrop(of: [UTType.plainText], delegate: DashboardDropDelegate(
                    item: card.type,
                    layoutManager: layoutManager
                ))
        } else {
            baseContent
        }
    }
    
    @ViewBuilder
    private func renderCard(_ config: DashboardCardConfig) -> some View {
        switch config.type {
        case .nutrition:
            Button(action: {
                selectedTab = 2
                NotificationCenter.default.post(name: NSNotification.Name("ResetNutritionToToday"), object: nil)
            }) {
                if config.size == .large {
                    NutritionSummaryCard(
                        consumed: consumedCalories,
                        goal: effectiveDailyCalorieGoal,
                        carbs: consumedCarbs,
                        protein: consumedProtein,
                        fat: consumedFat,
                        tolerance: nutritionTolerance,
                        eveningHour: calorieWarningEveningHour
                    )
                } else {
                    NutritionSummaryCardSmall(
                        consumed: consumedCalories,
                        goal: effectiveDailyCalorieGoal,
                        tolerance: nutritionTolerance,
                        eveningHour: calorieWarningEveningHour
                    )
                }
            }
            .buttonStyle(PlainButtonStyle())

        case .calorieBurn:
            Button(action: {
                showingCalorieBreakdown = true
            }) {
                if config.size == .large {
                    CalorieBurnSummaryCard(
                        consumed: consumedCalories,
                        effectiveGoal: effectiveDailyCalorieGoal,
                        activeBurned: todayActiveCalories,
                        totalBurned: todayTotalBurnedCalories
                    )
                } else {
                    CalorieBurnSummaryCardSmall(
                        consumed: consumedCalories,
                        effectiveGoal: effectiveDailyCalorieGoal,
                        activeBurned: todayActiveCalories,
                        totalBurned: todayTotalBurnedCalories
                    )
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .steps:
            NavigationLink(destination: StepTrackerView()) {
                if config.size == .large {
                    StepSummaryCard(steps: totalTodaySteps, goal: dailyStepGoal)
                } else {
                    StepSummaryCardSmall(steps: totalTodaySteps, goal: dailyStepGoal)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .weight:
            NavigationLink(destination: WeightTrackerView()) {
                if config.size == .large {
                    WeightSummaryCardLarge(entries: weightEntries)
                } else {
                    WeightSummaryCard(entries: weightEntries)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .training:
            Button(action: {
                if workoutManager.isWorkoutActive {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenActiveWorkout"), object: nil)
                } else if todayWorkouts.isEmpty {
                    UserDefaults.standard.set(0, forKey: "trainingSelectedTab")
                    selectedTab = 1
                } else {
                    UserDefaults.standard.set(2, forKey: "trainingSelectedTab")
                    if let latest = todayWorkouts.first {
                        UserDefaults.standard.set(latest.id.uuidString, forKey: "openHistorySessionId")
                    }
                    selectedTab = 1
                }
            }) {
                if config.size == .large {
                    TrainingSummaryCardLarge(workouts: todayWorkouts, activeSession: workoutManager.activeSession, lastWorkout: lastWorkout)
                } else {
                    TrainingSummaryCard(workouts: todayWorkouts, activeSession: workoutManager.activeSession, lastWorkout: lastWorkout)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .recovery:
            NavigationLink(destination: RecoveryView()) {
                if config.size == .large {
                    RecoveryCard()
                } else {
                    RecoveryCardSmall()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .energy:
            NavigationLink(destination: EnergyDetailView()) {
                if config.size == .large {
                    EnergyCardLarge()
                } else {
                    EnergyCardSmall()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .water:
            NavigationLink(destination: WaterTrackerView()) {
                if config.size == .large {
                    WaterTrackerCardLarge(entries: waterEntries)
                } else {
                    WaterTrackerCard(entries: waterEntries)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .sleep:
            NavigationLink(destination: SleepTrackerView()) {
                if config.size == .large {
                    SleepTrackerCardLarge()
                } else {
                    SleepTrackerCard()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        case .mood:
            if config.size == .large {
                MoodSummaryCard()
            } else {
                MoodSummaryCardSmall()
            }
        }
    }
    
    @ViewBuilder
    private func renderCardContent(_ config: DashboardCardConfig) -> some View {
        switch config.type {
        case .nutrition:
            if config.size == .large {
                NutritionSummaryCard(
                    consumed: consumedCalories,
                    goal: effectiveDailyCalorieGoal,
                    carbs: consumedCarbs,
                    protein: consumedProtein,
                    fat: consumedFat,
                    tolerance: nutritionTolerance,
                    eveningHour: calorieWarningEveningHour
                )
            } else {
                NutritionSummaryCardSmall(
                    consumed: consumedCalories,
                    goal: effectiveDailyCalorieGoal,
                    tolerance: nutritionTolerance,
                    eveningHour: calorieWarningEveningHour
                )
            }
        case .calorieBurn:
            if config.size == .large {
                CalorieBurnSummaryCard(
                    consumed: consumedCalories,
                    effectiveGoal: effectiveDailyCalorieGoal,
                    activeBurned: todayActiveCalories,
                    totalBurned: todayTotalBurnedCalories
                )
            } else {
                CalorieBurnSummaryCardSmall(
                    consumed: consumedCalories,
                    effectiveGoal: effectiveDailyCalorieGoal,
                    activeBurned: todayActiveCalories,
                    totalBurned: todayTotalBurnedCalories
                )
            }
        case .steps:
            if config.size == .large {
                StepSummaryCard(steps: totalTodaySteps, goal: dailyStepGoal)
            } else {
                StepSummaryCardSmall(steps: totalTodaySteps, goal: dailyStepGoal)
            }
        case .weight:
            if config.size == .large {
                WeightSummaryCardLarge(entries: weightEntries)
            } else {
                WeightSummaryCard(entries: weightEntries)
            }
        case .training:
            if config.size == .large {
                TrainingSummaryCardLarge(workouts: todayWorkouts, activeSession: workoutManager.activeSession, lastWorkout: lastWorkout)
            } else {
                TrainingSummaryCard(workouts: todayWorkouts, activeSession: workoutManager.activeSession, lastWorkout: lastWorkout)
            }
        case .recovery:
            if config.size == .large {
                RecoveryCard()
            } else {
                RecoveryCardSmall()
            }
        case .energy:
            if config.size == .large {
                EnergyCardLarge()
            } else {
                EnergyCardSmall()
            }
        case .water:
            if config.size == .large {
                WaterTrackerCardLarge(entries: waterEntries)
            } else {
                WaterTrackerCard(entries: waterEntries)
            }
        case .sleep:
            if config.size == .large {
                SleepTrackerCardLarge()
            } else {
                SleepTrackerCard()
            }
        case .mood:
            if config.size == .large {
                MoodSummaryCard()
            } else {
                MoodSummaryCardSmall()
            }
        }
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environment(\.modelContext, try! ModelContext(try! ModelContainer(for: WeightEntry.self, FoodEntry.self, WorkoutSession.self, StepEntry.self, WaterEntry.self)))
        .environment(WorkoutManager.shared)
}
