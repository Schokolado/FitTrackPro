import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    @MainActor
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), caloriesGoal: 2000, caloriesConsumed: 1200, protein: 50, proteinGoal: 150, carbs: 120, carbsGoal: 250, fat: 30, fatGoal: 70, lastWorkout: "Oberkörper", weight: 75.5, steps: 5400, stepGoal: 10000)
    }

    @MainActor
    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> ()) {
        let entry = fetchDashboardData(for: Date())
        completion(entry)
    }

    @MainActor
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = fetchDashboardData(for: Date())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    @MainActor
    private func fetchDashboardData(for date: Date) -> DashboardEntry {
        do {
            let container = try SharedContainer.create()
            let context = container.mainContext
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            formatter.timeZone = TimeZone.current
            let todayString = formatter.string(from: date)
            
            // 1. Calories and Macros
            let logsDescriptor = FetchDescriptor<DailyLog>()
            let logs = try context.fetch(logsDescriptor)
            let todayLog = logs.first(where: { $0.dateString == todayString })
            
            var caloriesConsumed: Double = 0
            var protein: Double = 0
            var carbs: Double = 0
            var fat: Double = 0
            
            if let entries = todayLog?.foodEntries {
                for entry in entries {
                    caloriesConsumed += entry.calories
                    protein += entry.proteinGrams
                    carbs += entry.carbsGrams
                    fat += entry.fatGrams
                }
            }
            
            // 2. Steps
            let stepsDescriptor = FetchDescriptor<StepEntry>()
            let stepsLogs = try context.fetch(stepsDescriptor)
            let todayStepsEntry = stepsLogs.first(where: { $0.dateString == todayString })
            let steps = todayStepsEntry?.steps ?? 0
            
            // 3. Workouts
            var lastWorkoutName = "Keine"
            let workoutDescriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
            if let lastWorkout = try context.fetch(workoutDescriptor).first {
                lastWorkoutName = lastWorkout.plan?.name ?? "Freies Training"
            }
            
            // 4. Weight
            var latestWeight: Double? = nil
            let weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            if let lastWeightEntry = try context.fetch(weightDescriptor).first {
                latestWeight = lastWeightEntry.weightKg
            }
            
            // 5. Goals
            let userDefaults = UserDefaults(suiteName: "group.com.riccardopfeiler.FitTrackPro") ?? .standard
            
            let calGoal = userDefaults.double(forKey: "dailyCalorieGoal")
            let pGoal = userDefaults.double(forKey: "nutritionGoalProtein")
            let cGoal = userDefaults.double(forKey: "nutritionGoalCarbs")
            let fGoal = userDefaults.double(forKey: "nutritionGoalFat")
            
            let stepGoalKey = userDefaults.integer(forKey: "dailyStepGoal")
            let stepGoalKey2 = userDefaults.integer(forKey: "daily_step_goal")
            let sGoal = max(stepGoalKey, stepGoalKey2)
            
            return DashboardEntry(
                date: date,
                caloriesGoal: calGoal > 0 ? calGoal : 2500,
                caloriesConsumed: caloriesConsumed,
                protein: protein,
                proteinGoal: pGoal > 0 ? pGoal : 150,
                carbs: carbs,
                carbsGoal: cGoal > 0 ? cGoal : 250,
                fat: fat,
                fatGoal: fGoal > 0 ? fGoal : 70,
                lastWorkout: lastWorkoutName,
                weight: latestWeight,
                steps: steps,
                stepGoal: sGoal > 0 ? sGoal : 10000
            )
        } catch {
            return DashboardEntry(date: date, caloriesGoal: 2500, caloriesConsumed: 0, protein: 0, proteinGoal: 150, carbs: 0, carbsGoal: 250, fat: 0, fatGoal: 70, lastWorkout: "Fehler", weight: nil, steps: 0, stepGoal: 10000)
        }
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let caloriesGoal: Double
    let caloriesConsumed: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double
    let lastWorkout: String
    let weight: Double?
    let steps: Int
    let stepGoal: Int
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(entry.caloriesConsumed / max(entry.caloriesGoal, 1)), 1.0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(entry.caloriesConsumed))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.8)
                    Text("/ \(Int(entry.caloriesGoal))")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 80)
            
            HStack(spacing: 8) {
                MacroBar(color: .red, label: "P", value: entry.protein, goal: entry.proteinGoal)
                MacroBar(color: .blue, label: "K", value: entry.carbs, goal: entry.carbsGoal)
                MacroBar(color: .yellow, label: "F", value: entry.fat, goal: entry.fatGoal)
            }
        }
    }
}

struct CalorieWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Kalorien")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(entry.caloriesConsumed / max(entry.caloriesGoal, 1)), 1.0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(entry.caloriesConsumed))")
                        .font(.system(.title2, design: .rounded).bold())
                        .minimumScaleFactor(0.8)
                    Text("/ \(Int(entry.caloriesGoal))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DashboardWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 8) {
            // Left: Calories
            CalorieWidgetView(entry: entry)
                .frame(maxWidth: .infinity)
            
            // Middle: Data
            VStack(alignment: .leading, spacing: 6) {
                // Macros
                VStack(alignment: .leading, spacing: 2) {
                    Text("Makros")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        MacroBar(color: .red, label: "P", value: entry.protein, goal: entry.proteinGoal)
                        MacroBar(color: .blue, label: "K", value: entry.carbs, goal: entry.carbsGoal)
                        MacroBar(color: .yellow, label: "F", value: entry.fat, goal: entry.fatGoal)
                    }
                }
                
                Spacer()
                
                // Workout
                VStack(alignment: .leading, spacing: 1) {
                    Text("Letztes Workout")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(entry.lastWorkout)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                }
                
                // Schritte
                VStack(alignment: .leading, spacing: 1) {
                    Text("Schritte")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(entry.steps)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(entry.steps >= entry.stepGoal ? .green : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            
            // Right: Actions
            VStack(spacing: 8) {
                Link(destination: URL(string: "fittrackpro://start-workout")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Workout")
                            .font(.system(size: 9, weight: .bold))
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
                
                Link(destination: URL(string: "fittrackpro://add-meal")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Mahlzeit")
                            .font(.system(size: 9, weight: .bold))
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
            }
            .frame(width: 65)
            .padding(.vertical, 4)
        }
    }
}

struct MacroBar: View {
    var color: Color
    var label: String
    var value: Double
    var goal: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 6, height: min(CGFloat(value / max(goal, 1)) * geometry.size.height, geometry.size.height))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 22)
            Text("\(Int(value))")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 18)
    }
}

struct WidgetSelectorView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .padding()
        case .systemMedium:
            DashboardWidgetView(entry: entry)
                .padding()
        default:
            SmallWidgetView(entry: entry)
                .padding()
        }
    }
}

struct FitTrackProWidget: Widget {
    let kind: String = "FitTrackProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetSelectorView(entry: entry)
                    .containerBackground(Color(UIColor.systemBackground).opacity(0.8), for: .widget)
            } else {
                WidgetSelectorView(entry: entry)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName("FitTrack Pro")
        .description("Behalte deine Kalorien und Fitness im Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
