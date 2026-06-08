import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    @MainActor
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), caloriesGoal: 2000, caloriesConsumed: 1200, protein: 50, carbs: 120, fat: 30, lastWorkout: "Oberkörper", weight: 75.5)
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
            
            var lastWorkoutName = "Keine"
            let workoutDescriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
            if let lastWorkout = try context.fetch(workoutDescriptor).first {
                lastWorkoutName = lastWorkout.plan?.name ?? "Freies Training"
            }
            
            var latestWeight: Double? = nil
            let weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            if let lastWeightEntry = try context.fetch(weightDescriptor).first {
                latestWeight = lastWeightEntry.weightKg
            }
            
            let userDefaults = UserDefaults(suiteName: "group.com.riccardopfeiler.FitTrackPro") ?? .standard
            let caloriesGoal = userDefaults.integer(forKey: "calorieGoal") == 0 ? 2000 : userDefaults.integer(forKey: "calorieGoal")
            
            return DashboardEntry(
                date: date,
                caloriesGoal: Double(caloriesGoal),
                caloriesConsumed: caloriesConsumed,
                protein: protein,
                carbs: carbs,
                fat: fat,
                lastWorkout: lastWorkoutName,
                weight: latestWeight
            )
        } catch {
            return DashboardEntry(date: date, caloriesGoal: 2000, caloriesConsumed: 0, protein: 0, carbs: 0, fat: 0, lastWorkout: "Keine Daten", weight: nil)
        }
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let caloriesGoal: Double
    let caloriesConsumed: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let lastWorkout: String
    let weight: Double?
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
        HStack(spacing: 20) {
            CalorieWidgetView(entry: entry)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Letztes Workout")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.lastWorkout)
                        .font(.footnote).bold()
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gewicht")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let w = entry.weight {
                        Text("\(String(format: "%.1f", w)) kg")
                            .font(.footnote).bold()
                    } else {
                        Text("-- kg")
                            .font(.footnote).bold()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WidgetSelectorView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            CalorieWidgetView(entry: entry)
                .padding()
        case .systemMedium:
            DashboardWidgetView(entry: entry)
                .padding()
        default:
            CalorieWidgetView(entry: entry)
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
