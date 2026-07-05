import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutManager.self) private var workoutManager
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Double = 2500
    @AppStorage("daily_step_goal") private var dailyStepGoal: Int = 10000
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("cached_today_steps") private var cachedTodaySteps: Int = 0
    @AppStorage("cached_today_steps_date") private var cachedTodayStepsDate: String = ""
    
    @State private var todaySteps: Int = 0
    
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
    
    var yesterdayWorkout: WorkoutSession? {
        let calendar = Calendar.current
        return workouts.first { calendar.isDateInYesterday($0.startTime) && $0.endTime != nil }
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
    @State private var navId = UUID()
    @StateObject private var layoutManager = DashboardLayoutManager()
    @State private var currentDraggedItem: DashboardCardType?
    @State private var isEditMode = false
    
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
                        let rows = groupCardsForRows(layoutManager.cards)
                        ForEach(rows.indices, id: \.self) { index in
                            let row = rows[index]
                            if row[0].size == .large {
                                // Large card
                                renderCardWithEditOverlay(row[0])
                                    .padding(.horizontal)
                            } else {
                                // Small cards
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                    renderCardWithEditOverlay(row[0])
                                    if row.count > 1 {
                                        renderCardWithEditOverlay(row[1])
                                    } else {
                                        Color.clear
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await refreshSteps()
                }
                .scrollContentBackground(.hidden)
                .background(Color.backgroundPrimary.ignoresSafeArea())
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isEditMode {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Fertig") {
                                withAnimation { isEditMode = false }
                            }
                            .fontWeight(.bold)
                        }
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button(action: {
                                    withAnimation { isEditMode = true }
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
        }
        .id(navId)
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
                Task {
                    await refreshSteps()
                }
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
    
    private func groupCardsForRows(_ cards: [DashboardCardConfig]) -> [[DashboardCardConfig]] {
        var rows: [[DashboardCardConfig]] = []
        var currentRow: [DashboardCardConfig] = []
        
        for card in cards {
            if card.size == .large {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                rows.append([card])
            } else {
                currentRow.append(card)
                if currentRow.count == 2 {
                    rows.append(currentRow)
                    currentRow = []
                }
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
    
    @ViewBuilder
    private func renderCardWithEditOverlay(_ card: DashboardCardConfig) -> some View {
        renderCard(card)
            .allowsHitTesting(!isEditMode)
            .jiggle(isEnabled: isEditMode)
            .overlay(alignment: .topTrailing) {
                if isEditMode {
                    Button {
                        withAnimation { layoutManager.toggleSize(for: card.type) }
                    } label: {
                        Image(systemName: card.size == .large ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.up.left.and.arrow.down.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white, .gray.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding(-8)
                    .transition(.scale)
                }
            }
            .onDrag {
                if isEditMode {
                    self.currentDraggedItem = card.type
                    return NSItemProvider(object: card.type.rawValue as NSString)
                }
                return NSItemProvider()
            }
            .onDrop(of: [.text], delegate: DashboardDropDelegate(item: card.type, currentDraggedItem: $currentDraggedItem, layoutManager: layoutManager))
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
                    NutritionSummaryCard(consumed: consumedCalories, goal: dailyCalorieGoal, carbs: consumedCarbs, protein: consumedProtein, fat: consumedFat)
                } else {
                    NutritionSummaryCardSmall(consumed: consumedCalories, goal: dailyCalorieGoal)
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
                    TrainingSummaryCardLarge(workouts: todayWorkouts, activeSession: workoutManager.activeSession, yesterdayWorkout: yesterdayWorkout)
                } else {
                    TrainingSummaryCard(workouts: todayWorkouts, activeSession: workoutManager.activeSession, yesterdayWorkout: yesterdayWorkout)
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
}

#Preview {
    DashboardView(selectedTab: .constant(0))
}
import SwiftUI
import SwiftData


