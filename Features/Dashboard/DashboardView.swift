import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Double = 2500
    @AppStorage("userName") private var userName: String = ""
    
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var allFoodEntries: [FoodEntry]
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    
    var todayFoodEntries: [FoodEntry] {
        let todayString = Date().iso8601String()
        return allFoodEntries.filter { $0.dailyLog?.dateString == todayString }
    }
    
    var todayWorkouts: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.startTime) }
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
                    
                    // Nutrition Card
                    Button(action: {
                        selectedTab = 2 // Tab Index für Ernährung
                        NotificationCenter.default.post(name: NSNotification.Name("ResetNutritionToToday"), object: nil)
                    }) {
                        NutritionSummaryCard(
                            consumed: consumedCalories,
                            goal: dailyCalorieGoal,
                            carbs: consumedCarbs,
                            protein: consumedProtein,
                            fat: consumedFat
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    // Grid for Weight and Training
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        NavigationLink(destination: WeightTrackerView()) {
                            WeightSummaryCard(entries: weightEntries)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if todayWorkouts.isEmpty {
                                UserDefaults.standard.set(0, forKey: "trainingSelectedTab") // Pläne
                            } else {
                                UserDefaults.standard.set(2, forKey: "trainingSelectedTab") // Historie
                                if let latest = todayWorkouts.first {
                                    UserDefaults.standard.set(latest.id.uuidString, forKey: "openHistorySessionId")
                                }
                            }
                            selectedTab = 1 // Tab Index für Training
                        }) {
                            TrainingSummaryCard(workouts: todayWorkouts)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 120) // Platz für Tabbar & MiniPlayer
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .id(navId)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 0 {
                navId = UUID()
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
}

#Preview {
    DashboardView(selectedTab: .constant(0))
}
import SwiftUI
import SwiftData


