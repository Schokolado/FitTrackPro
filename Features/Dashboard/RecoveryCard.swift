import SwiftUI
import SwiftData

struct RecoveryCard: View {
    @Query private var workouts: [WorkoutSession]
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var manualSleeps: [SleepEntry]
    
    @AppStorage(AppStorageKeys.dailySleepGoalHours) private var sleepGoalHours: Double = 8.0
    
    @State private var result: RecoveryResult?
    @State private var isLoading = true
    
    var colorForScore: Color {
        guard let score = result?.score else { return .teal }
        if score < 40 { return .red }
        if score < 65 { return .orange }
        if score < 85 { return .green }
        return .teal
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(colorForScore.opacity(0.2), lineWidth: 10)
                
                if let score = result?.score {
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(colorForScore, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: score)
                }
                
                VStack(spacing: 2) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundColor(colorForScore)
                        .font(.caption)
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else if let score = result?.score {
                        Text("\(score)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Text("--")
                    }
                }
            }
            .frame(width: 90, height: 90)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                Text("Akku / Recovery")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let r = result {
                    Text(r.level.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Lade Daten...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
        .task {
            await calculate()
        }
    }
    
    private func calculate() async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure HealthKit authorization
        try? await HealthKitService.shared.requestAuthorization()
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        var hkLastNightSleep: Double?
        var hrvScore: Double?
        var hrvBaseline: Double?
        var rhrScore: Double?
        var rhrBaseline: Double?
        
        if let sleep = try? await HealthKitService.shared.fetchSleepData(for: today), sleep.totalDurationMinutes > 0 {
            hkLastNightSleep = sleep.totalDurationMinutes / 60.0
        } else if let sleep = try? await HealthKitService.shared.fetchSleepData(for: yesterday), sleep.totalDurationMinutes > 0 {
            hkLastNightSleep = sleep.totalDurationMinutes / 60.0
        }
        
        hrvScore = try? await HealthKitService.shared.fetchHRV(for: today)
        if hrvScore == nil { hrvScore = try? await HealthKitService.shared.fetchHRV(for: yesterday) }
        if hrvScore == nil { hrvScore = try? await HealthKitService.shared.fetchHRVBaseline(days: 7, upTo: Calendar.current.date(byAdding: .day, value: 1, to: today)!) }
        if hrvScore != nil { hrvBaseline = try? await HealthKitService.shared.fetchHRVBaseline(days: 7, upTo: today) }
        
        rhrScore = try? await HealthKitService.shared.fetchRestingHeartRate(for: today)
        if rhrScore == nil { rhrScore = try? await HealthKitService.shared.fetchRestingHeartRate(for: yesterday) }
        if rhrScore == nil { rhrScore = try? await HealthKitService.shared.fetchRHRBaseline(days: 7, upTo: Calendar.current.date(byAdding: .day, value: 1, to: today)!) }
        if rhrScore != nil { rhrBaseline = try? await HealthKitService.shared.fetchRHRBaseline(days: 7, upTo: today) }
        
        let calendar = Calendar.current
        let completedWorkouts = workouts.filter { $0.endTime != nil }
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let recentWorkouts = completedWorkouts.filter { $0.startTime >= threeDaysAgo }
        
        var daysSinceLastWorkout = 3
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
        
        result = RecoveryCalculator.calculate(
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
