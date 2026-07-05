import SwiftUI
import SwiftData

// MARK: - NutritionSummaryCardSmall

struct NutritionSummaryCardSmall: View {
    let consumed: Double
    let goal: Double
    
    var progress: Double {
        min(consumed / max(goal, 1), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ernährung")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(consumed)) kcal")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("von \(Int(goal)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.brand.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
                .frame(width: 44, height: 44)
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

// MARK: - StepSummaryCardSmall

struct StepSummaryCardSmall: View {
    let steps: Int
    let goal: Int
    
    var progress: Double {
        min(Double(steps) / max(Double(goal), 1), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "figure.walk")
                    .foregroundColor(.green)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schritte")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(steps)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("von \(goal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
                .frame(width: 44, height: 44)
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

// MARK: - RecoveryCardSmall

struct RecoveryCardSmall: View {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "battery.100.bolt")
                    .foregroundColor(.cyan)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let r = result {
                    Text("\(r.score)%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorForScore)
                    
                    Text(r.level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("--%")
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

// MARK: - MoodSummaryCardSmall

struct MoodSummaryCardSmall: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "face.smiling")
                    .foregroundColor(.yellow)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Stimmung")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Coming Soon")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.yellow)
                    .clipShape(Capsule())
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
