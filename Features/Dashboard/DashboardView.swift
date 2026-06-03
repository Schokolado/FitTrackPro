import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Double = 2500
    @AppStorage("userName") private var userName: String = ""
    
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    
    var todayFoodEntries: [FoodEntry] {
        foodEntries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    var todayWorkouts: [WorkoutSession] {
        workouts.filter { Calendar.current.isDateInToday($0.startTime) }
    }
    
    var consumedCalories: Double {
        todayFoodEntries.reduce(0) { $0 + $1.calories }
    }
    
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
                    }) {
                        NutritionSummaryCard(
                            consumed: consumedCalories,
                            goal: dailyCalorieGoal
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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

struct NutritionSummaryCard: View {
    let consumed: Double
    let goal: Double
    
    var progress: Double {
        min(consumed / max(goal, 1), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.brand.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.brand)
                        .font(.caption)
                    Text("\(Int(consumed))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 90, height: 90)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                Text("Ernährung heute")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(Int(max(goal - consumed, 0))) kcal verbleibend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                HStack(spacing: 12) {
                    MacroBadge(label: "K", color: .blue)
                    MacroBadge(label: "P", color: .purple)
                    MacroBadge(label: "F", color: .orange)
                }
                .padding(.top, 4)
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}

struct MacroBadge: View {
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

struct WeightSummaryCard: View {
    let entries: [WeightEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.brand)
                    .font(.title2)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Gewicht")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let latest = entries.first {
                    Text("\(latest.weightKg, specifier: "%.1f") kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                    if entries.count > 1 {
                        let diff = latest.weightKg - entries[1].weightKg
                        let color: Color = diff > 0 ? .red : (diff < 0 ? .green : .secondary)
                        Text(String(format: "%@%.1f kg", diff > 0 ? "+" : "", diff))
                            .font(.caption.bold())
                            .foregroundColor(color)
                    } else {
                        Text("Erster Eintrag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("-- kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}

struct TrainingSummaryCard: View {
    let workouts: [WorkoutSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.title2)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let workout = workouts.first {
                    Text("Erledigt")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text(workout.plan?.name ?? "Freies Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Anstehend")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Tippen zum Starten")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}
