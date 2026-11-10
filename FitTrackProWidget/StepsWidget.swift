import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Data Models

struct StepDayItem: Identifiable {
    let id: String
    let label: String
    let steps: Int
    let isToday: Bool
}

struct StepsEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let stepGoal: Int
    let weeklyDays: [StepDayItem]
    
    var progress: Double {
        min(Double(steps) / max(Double(stepGoal), 1), 1.0)
    }
    
    var remainingSteps: Int {
        max(stepGoal - steps, 0)
    }
    
    var estimatedKm: Double {
        Double(steps) * 0.00075
    }
}

// MARK: - Timeline Provider

struct StepsProvider: TimelineProvider {
    @MainActor
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(
            date: Date(),
            steps: 7420,
            stepGoal: 10000,
            weeklyDays: sampleWeeklyDays()
        )
    }
    
    @MainActor
    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> ()) {
        completion(fetchStepsData(for: Date()))
    }
    
    @MainActor
    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> ()) {
        let entry = fetchStepsData(for: Date())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    @MainActor
    private func fetchStepsData(for date: Date) -> StepsEntry {
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        let todayString = formatter.string(from: date)
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.riccardopfeiler.FitTrackPro") ?? .standard
        
        let goal1 = sharedDefaults.integer(forKey: "daily_step_goal")
        let goal2 = sharedDefaults.integer(forKey: "dailyStepGoal")
        let stepGoal = max(goal1, goal2) > 0 ? max(goal1, goal2) : 10000
        
        // Cached HealthKit steps for today
        let cachedDate = sharedDefaults.string(forKey: "cached_today_steps_date") ?? ""
        let cachedHKToday = (cachedDate == todayString) ? sharedDefaults.integer(forKey: "cached_today_steps") : 0
        
        // Weekly HealthKit steps cache [dateString: Int]
        var weeklyHKCache: [String: Int] = [:]
        if let cacheData = sharedDefaults.data(forKey: "weekly_healthkit_steps_cache"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: cacheData) {
            weeklyHKCache = decoded
        }
        
        // Manual entries from SwiftData SharedContainer
        var manualByDay: [String: Int] = [:]
        if let container = try? SharedContainer.create() {
            let context = container.mainContext
            let descriptor = FetchDescriptor<StepEntry>()
            if let entries = try? context.fetch(descriptor) {
                for entry in entries {
                    manualByDay[entry.dateString, default: 0] += entry.steps
                }
            }
        }
        
        let todayTotal = cachedHKToday + (manualByDay[todayString] ?? 0)
        
        // Build last 7 days
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "de_DE")
        dayFormatter.dateFormat = "EEEEE" // Single letter: M, D, M, D, F, S, S
        
        var weeklyDays: [StepDayItem] = []
        for offset in (0..<7).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            let dayStr = formatter.string(from: dayDate)
            let isToday = offset == 0
            let hkSteps = isToday ? max(cachedHKToday, weeklyHKCache[dayStr] ?? 0) : (weeklyHKCache[dayStr] ?? 0)
            let total = hkSteps + (manualByDay[dayStr] ?? 0)
            let label = dayFormatter.string(from: dayDate)
            weeklyDays.append(StepDayItem(id: dayStr, label: label, steps: total, isToday: isToday))
        }
        
        return StepsEntry(
            date: date,
            steps: todayTotal,
            stepGoal: stepGoal,
            weeklyDays: weeklyDays
        )
    }
    
    private func sampleWeeklyDays() -> [StepDayItem] {
        let labels = ["M", "D", "M", "D", "F", "S", "S"]
        let values = [6200, 10400, 8100, 11200, 5300, 9800, 7420]
        return zip(labels, values).enumerated().map { idx, pair in
            StepDayItem(id: "\(idx)", label: pair.0, steps: pair.1, isToday: idx == 6)
        }
    }
}

// MARK: - Formatting Helpers

private func formattedSteps(_ count: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "de_DE")
    return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
}

private func compactSteps(_ count: Int) -> String {
    if count >= 1000 {
        let k = Double(count) / 1000.0
        return String(format: "%.1fk", k)
    }
    return "\(count)"
}

// MARK: - Widget Views

struct StepsSmallWidgetView: View {
    let entry: StepsEntry
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                Text("Schritte")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption2.bold())
                    .foregroundColor(entry.steps >= entry.stepGoal ? .green : .secondary)
                    .fixedSize()
            }
            
            Spacer(minLength: 0)
            
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 1) {
                    Text(formattedSteps(entry.steps))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/ \(compactSteps(entry.stepGoal))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 80, height: 80)
            
            Spacer(minLength: 0)
            
            Text(entry.remainingSteps == 0 ? "Ziel erreicht!" : "Noch \(formattedSteps(entry.remainingSteps))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(entry.remainingSteps == 0 ? .green : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(2)
    }
}

struct StepsMediumWidgetView: View {
    let entry: StepsEntry
    
    private var maxChartSteps: Int {
        max(entry.stepGoal, entry.weeklyDays.map(\.steps).max() ?? 10000)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Circular Ring & Today's Details
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 9)
                    
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(formattedSteps(entry.steps))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: 82, height: 82)
                
                Text(entry.remainingSteps == 0 ? "Ziel erreicht!" : "Noch \(formattedSteps(entry.remainingSteps))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(entry.remainingSteps == 0 ? .green : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 100)
            
            // Right: 7-Day Chart + Meta
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("7 Tage")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "~%.1f km", entry.estimatedKm))
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                }
                
                GeometryReader { geo in
                    let maxVal = max(Double(maxChartSteps), 1)
                    let goalRatio = min(Double(entry.stepGoal) / maxVal, 1.0)
                    let chartHeight = max(geo.size.height - 16, 20)
                    
                    ZStack(alignment: .bottom) {
                        // Goal dashed line
                        Path { path in
                            let y = chartHeight * (1.0 - goalRatio)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.green.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(height: chartHeight)
                        .offset(y: -16)
                        
                        // Bars
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(entry.weeklyDays) { day in
                                let ratio = min(max(Double(day.steps) / maxVal, 0.06), 1.0)
                                let hitGoal = day.steps >= entry.stepGoal
                                
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(hitGoal ? Color.green : (day.isToday ? Color.green.opacity(0.75) : Color.green.opacity(0.35)))
                                        .frame(height: max(chartHeight * ratio, 4))
                                    
                                    Text(day.label)
                                        .font(.system(size: 9, weight: day.isToday ? .bold : .medium))
                                        .foregroundColor(day.isToday ? .primary : .secondary)
                                        .frame(height: 12)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(2)
    }
}

struct StepsAccessoryCircularView: View {
    let entry: StepsEntry
    
    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(compactSteps(entry.steps))
                .font(.system(.caption2, design: .rounded).bold())
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct StepsAccessoryRectangularView: View {
    let entry: StepsEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                Text("Schritte")
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("\(formattedSteps(entry.steps)) / \(formattedSteps(entry.stepGoal))")
                .font(.system(.subheadline, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            ProgressView(value: entry.progress)
        }
    }
}

struct StepsWidgetEntryView: View {
    let entry: StepsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StepsSmallWidgetView(entry: entry)
            case .systemMedium:
                StepsMediumWidgetView(entry: entry)
            case .accessoryCircular:
                StepsAccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                StepsAccessoryRectangularView(entry: entry)
            default:
                StepsSmallWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "fittrackpro://steps"))
    }
}

// MARK: - Widget Configuration

struct StepsWidget: Widget {
    let kind: String = "StepsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepsProvider()) { entry in
            if #available(iOS 17.0, *) {
                StepsWidgetEntryView(entry: entry)
                    .containerBackground(Color(UIColor.systemBackground).opacity(0.85), for: .widget)
            } else {
                StepsWidgetEntryView(entry: entry)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName("Schritte")
        .description("Zeigt deine heutigen Schritte, das Tagesziel und den 7-Tage-Verlauf.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
