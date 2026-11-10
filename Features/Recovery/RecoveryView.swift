import SwiftUI
import SwiftData

struct RecoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [WorkoutSession]
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var manualSleeps: [SleepEntry]
    
    @AppStorage(AppStorageKeys.dailySleepGoalHours) private var sleepGoalHours: Double = 8.0
    @AppStorage(AppStorageKeys.dailyStepGoal) private var dailyStepGoal: Int = 10000
    
    @State private var recoveryResult: RecoveryResult?
    @State private var isLoading = true
    
    // State for Bio metrics
    @State private var hrvScore: Double?
    @State private var hrvBaseline: Double?
    @State private var rhrScore: Double?
    @State private var rhrBaseline: Double?
    @State private var hkLastNightSleep: Double?
    @State private var todaySteps: Int = 0
    @State private var todayActiveKcal: Double = 0
    @State private var weekWorkoutsCount: Int = 0
    @State private var weekDurationMinutes: Int = 0
    @State private var weekTotalVolumeKg: Double = 0
    
    var colorForScore: Color {
        guard let score = recoveryResult?.score else { return .teal }
        if score < 40 { return .red }
        if score < 65 { return .orange }
        if score < 85 { return .green }
        return .teal
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Berechne Recovery...")
                        .padding(.top, 50)
                } else if let result = recoveryResult {
                    // Header Circular Progress
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(colorForScore.opacity(0.2), lineWidth: 18)
                            
                            Circle()
                                .trim(from: 0, to: Double(result.score) / 100.0)
                                .stroke(colorForScore, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: result.score)
                            
                            VStack(spacing: 4) {
                                Text("\(result.score)%")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(colorForScore)
                                
                                Text("Recovery")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 160, height: 160)
                        .padding(.top, 20)
                        
                        Text(result.level.description)
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text("Werte mit Apple Watch oder Tracker akkurater")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }
                    
                    // Belastung / Erholung / Schlaf (3 Kreise)
                    vitalRingsSection(for: result)
                    
                    // Kompakte Aktivitätszusammenfassung (Heute & 7 Tage)
                    activitySummarySection
                    
                    // Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Aufschlüsselung")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Sleep
                        NavigationLink(destination: RecoveryFactorDetailView(factor: .sleep, result: result)) {
                            breakdownRow(
                                icon: "moon.zzz.fill",
                                color: .indigo,
                                title: "Schlaf",
                                subtitle: "\(result.sleepScore) / \(result.sleepMax) Punkte",
                                progress: Double(result.sleepScore) / Double(max(result.sleepMax, 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Training Load
                        NavigationLink(destination: RecoveryFactorDetailView(factor: .training, result: result)) {
                            breakdownRow(
                                icon: "figure.run",
                                color: .blue,
                                title: "Trainingsbelastung",
                                subtitle: "\(result.trainingScore) / \(result.trainingMax) Punkte",
                                progress: Double(result.trainingScore) / Double(max(result.trainingMax, 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Rest
                        NavigationLink(destination: RecoveryFactorDetailView(factor: .rest, result: result)) {
                            breakdownRow(
                                icon: "pause.circle.fill",
                                color: .orange,
                                title: "Erholungstage",
                                subtitle: "\(result.restScore) / \(result.restMax) Punkte",
                                progress: Double(result.restScore) / Double(max(result.restMax, 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Bio
                        if result.usesHRV, let hrvPoints = result.hrvScore, let hrvMax = result.hrvMax {
                            NavigationLink(destination: RecoveryFactorDetailView(factor: .bio, result: result)) {
                                breakdownRow(
                                    icon: "heart.fill",
                                    color: .red,
                                    title: "HRV / Ruheherzfrequenz",
                                    subtitle: "\(hrvPoints) / \(hrvMax) Punkte",
                                    progress: Double(hrvPoints) / Double(max(hrvMax, 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Messwerte (raw data points)
                    if result.rawLastNightSleepHours != nil || result.rawHRV != nil || result.rawRHR != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Messwerte")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if let sleep = result.rawLastNightSleepHours {
                                    let h = Int(sleep)
                                    let m = Int((sleep - Double(h)) * 60)
                                    dataCard(icon: "moon.zzz.fill", color: .indigo, title: "Schlaf", value: "\(h)h \(m)m", subtitle: "Ziel: \(Int(result.rawSleepGoalHours))h")
                                }
                                
                                dataCard(icon: "figure.run", color: .blue, title: "Workouts (3 Tage)", value: "\(result.rawWorkoutSessionsLast3Days)", subtitle: result.rawDaysSinceLastWorkout == 1 ? "\(result.rawDaysSinceLastWorkout) Tag Pause" : "\(result.rawDaysSinceLastWorkout) Tage Pause")
                                
                                if let hrv = result.rawHRV {
                                    let baselineText = result.rawHRVBaseline != nil ? "Ø \(Int(result.rawHRVBaseline!)) ms" : ""
                                    dataCard(icon: "waveform.path.ecg", color: .green, title: "HRV", value: "\(Int(hrv)) ms", subtitle: baselineText)
                                }
                                
                                if let rhr = result.rawRHR {
                                    let baselineText = result.rawRHRBaseline != nil ? "Ø \(Int(result.rawRHRBaseline!)) bpm" : ""
                                    dataCard(icon: "heart.fill", color: .red, title: "Ruhepuls", value: "\(Int(rhr)) bpm", subtitle: baselineText)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Akku / Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await calculateRecovery()
        }
    }
    
    private func breakdownRow(icon: String, color: Color, title: String, subtitle: String, progress: Double) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(color)
                            .frame(width: max(0, geo.size.width * progress), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }
    
    private func dataCard(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
    }
    
    private func vitalRingsSection(for result: RecoveryResult) -> some View {
        let strainPercent = computeStrainPercent(for: result)
        let sleepPercent = computeSleepPercent(for: result)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Belastung • Erholung • Schlaf")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                vitalRingItem(
                    title: "Belastung",
                    percent: strainPercent,
                    subtitle: "\(Int(todayActiveKcal)) kcal",
                    color: .orange
                )
                vitalRingItem(
                    title: "Erholung",
                    percent: result.score,
                    subtitle: result.level.rawValue,
                    color: colorForScore
                )
                vitalRingItem(
                    title: "Schlaf",
                    percent: sleepPercent,
                    subtitle: formattedSleepDuration(result.rawLastNightSleepHours),
                    color: .indigo
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.backgroundSecondary)
            )
            .padding(.horizontal)
        }
    }
    
    private func vitalRingItem(title: String, percent: Int, subtitle: String, color: Color) -> some View {
        let clamped = min(max(percent, 0), 100)
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: Double(clamped) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clamped)
                Text("\(clamped)%")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(color)
            }
            .frame(width: 72, height: 72)
            
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var activitySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktivitätszusammenfassung")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                dataCard(
                    icon: "figure.walk",
                    color: .green,
                    title: "Schritte heute",
                    value: todaySteps.formatted(),
                    subtitle: "Ziel: \(dailyStepGoal.formatted())"
                )
                dataCard(
                    icon: "flame.fill",
                    color: .orange,
                    title: "Aktive Kalorien",
                    value: "\(Int(todayActiveKcal)) kcal",
                    subtitle: "Heute verbrannt"
                )
                dataCard(
                    icon: "dumbbell.fill",
                    color: .blue,
                    title: "Workouts (7 Tage)",
                    value: "\(weekWorkoutsCount)",
                    subtitle: "\(weekDurationMinutes) Min. gesamt"
                )
                dataCard(
                    icon: "scalemass.fill",
                    color: .purple,
                    title: "Volumen (7 Tage)",
                    value: formattedVolume(weekTotalVolumeKg),
                    subtitle: "Abgeschlossene Sätze"
                )
            }
            .padding(.horizontal)
        }
    }
    
    private func computeStrainPercent(for result: RecoveryResult) -> Int {
        let sessionLoad = min(1.0, Double(result.rawWorkoutSessionsLast3Days) / 3.0)
        if todayActiveKcal > 0 || todaySteps > 0 {
            let calorieLoad = min(1.0, todayActiveKcal / 600.0)
            let stepLoad = min(1.0, Double(todaySteps) / Double(max(dailyStepGoal, 1)))
            let blended = (0.4 * sessionLoad) + (0.35 * calorieLoad) + (0.25 * stepLoad)
            return Int((min(1.0, max(0.0, blended)) * 100.0).rounded())
        }
        return Int((sessionLoad * 100.0).rounded())
    }
    
    private func computeSleepPercent(for result: RecoveryResult) -> Int {
        if let sleepHours = result.rawLastNightSleepHours {
            let ratio = min(1.0, max(0.0, sleepHours / max(result.rawSleepGoalHours, 1.0)))
            return Int((ratio * 100.0).rounded())
        }
        let fallback = Double(result.sleepScore) / Double(max(result.sleepMax, 1))
        return Int((min(1.0, max(0.0, fallback)) * 100.0).rounded())
    }
    
    private func formattedSleepDuration(_ hours: Double?) -> String {
        guard let hours else { return "Keine Daten" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
    
    private func formattedVolume(_ kg: Double) -> String {
        if kg >= 1000 {
            return String(format: "%.1f t", kg / 1000.0)
        }
        return "\(Int(kg)) kg"
    }
    
    private func calculateRecovery() async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure HealthKit authorization
        try? await HealthKitService.shared.requestAuthorization()
        
        // 1. Fetch HealthKit Data — each fetch isolated so one failure doesn't abort the rest
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // Sleep
        if let sleep = try? await HealthKitService.shared.fetchSleepData(for: today), sleep.totalDurationMinutes > 0 {
            hkLastNightSleep = sleep.totalDurationMinutes / 60.0
        } else if let sleep = try? await HealthKitService.shared.fetchSleepData(for: yesterday), sleep.totalDurationMinutes > 0 {
            hkLastNightSleep = sleep.totalDurationMinutes / 60.0
        }
        
        // HRV: try today, yesterday, then last 7 days
        hrvScore = try? await HealthKitService.shared.fetchHRV(for: today)
        if hrvScore == nil {
            hrvScore = try? await HealthKitService.shared.fetchHRV(for: yesterday)
        }
        if hrvScore == nil {
            hrvScore = try? await HealthKitService.shared.fetchHRVBaseline(days: 7, upTo: Calendar.current.date(byAdding: .day, value: 1, to: today)!)
        }
        if hrvScore != nil {
            hrvBaseline = try? await HealthKitService.shared.fetchHRVBaseline(days: 7, upTo: today)
        }
        
        // RHR: try today, yesterday, then last 7 days
        rhrScore = try? await HealthKitService.shared.fetchRestingHeartRate(for: today)
        if rhrScore == nil {
            rhrScore = try? await HealthKitService.shared.fetchRestingHeartRate(for: yesterday)
        }
        if rhrScore == nil {
            rhrScore = try? await HealthKitService.shared.fetchRHRBaseline(days: 7, upTo: Calendar.current.date(byAdding: .day, value: 1, to: today)!)
        }
        if rhrScore != nil {
            rhrBaseline = try? await HealthKitService.shared.fetchRHRBaseline(days: 7, upTo: today)
        }
        
        // Today's Activity (Steps & Active Calories)
        todaySteps = (try? await HealthKitService.shared.fetchSteps(for: today)) ?? 0
        todayActiveKcal = (try? await HealthKitService.shared.fetchActiveEnergyBurned(for: today)) ?? 0
        
        // 2. Fetch DB Data (Workouts)
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        let completedWorkouts = workouts.filter { $0.endTime != nil }
        let recentWorkouts = completedWorkouts.filter { $0.startTime >= threeDaysAgo }
        let weeklyWorkouts = completedWorkouts.filter { $0.startTime >= sevenDaysAgo }
        
        weekWorkoutsCount = weeklyWorkouts.count
        weekDurationMinutes = weeklyWorkouts.reduce(0) { sum, session in
            guard let end = session.endTime else { return sum }
            return sum + max(0, Int(end.timeIntervalSince(session.startTime) / 60))
        }
        weekTotalVolumeKg = weeklyWorkouts.reduce(0.0) { sum, session in
            let sessionVol = (session.sets ?? [])
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + ($1.actualWeight * Double($1.actualReps)) }
            return sum + sessionVol
        }
        
        var daysSinceLastWorkout = 3 // default max
        if let last = completedWorkouts.max(by: { $0.startTime < $1.startTime }) {
            let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.startTime), to: calendar.startOfDay(for: today))
            daysSinceLastWorkout = max(0, components.day ?? 3)
        }
        
        var sleepHours: Double?
        if let hk = hkLastNightSleep {
            sleepHours = hk
        } else if let manual = manualSleeps.first, calendar.isDateInToday(manual.wakeTime) || calendar.isDateInYesterday(manual.wakeTime) {
            sleepHours = manual.durationMinutes / 60.0
        }
        
        // 3. Calculate
        recoveryResult = RecoveryCalculator.calculate(
            lastNightSleepHours: sleepHours,
            sleepGoalHours: sleepGoalHours,
            workoutSessionsLast3Days: recentWorkouts.count,
            daysSinceLastWorkout: daysSinceLastWorkout,
            hrvScore: hrvScore,
            restingHR: rhrScore,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline
        )
    }
}

#Preview {
    NavigationStack {
        RecoveryView()
    }
}
