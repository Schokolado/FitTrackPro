import SwiftUI
import SwiftData

// MARK: - EnergyCardSmall

struct EnergyCardSmall: View {
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var sleepEntries: [SleepEntry]

    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    
    @State private var result: EnergyResult?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "bolt.batteryblock.fill")
                    .foregroundColor(.yellow)
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
                    Text("Tagesenergie")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        ProgressView()
                    } else if let res = result {
                        HStack(spacing: 8) {
                            Text("\(res.currentEnergy)%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(energyColor(res.currentEnergy))
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                }
                
                Spacer()
                
                if let res = result {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(res.currentEnergy) / 100.0)
                            .stroke(energyColor(res.currentEnergy), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 40)
                    }
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
        .onAppear {
            Task { await calculateEnergy() }
        }
    }
    
    private func energyColor(_ val: Int) -> Color {
        if val > 60 { return .green }
        if val > 30 { return .yellow }
        return .red
    }
    
    private func calculateEnergy() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let todayWorkouts = workouts.filter { calendar.isDateInToday($0.startTime) }
        
        // Letzte Nacht Schlaf
        let lastNightSleep = sleepEntries.first { calendar.isDate($0.wakeTime, inSameDayAs: today) || calendar.isDate($0.wakeTime, inSameDayAs: yesterday) }
        let sleepHours = lastNightSleep?.durationMinutes != nil ? lastNightSleep!.durationMinutes / 60.0 : nil
        
        // Heutige Schritte und Kalorien
        let steps = try? await HealthKitService.shared.fetchSteps(for: today)
        let cals = try? await HealthKitService.shared.fetchActiveEnergyBurned(for: today)
        
        // Heutiges Recovery
        let rResult = RecoveryCalculator.calculate(
            lastNightSleepHours: sleepHours,
            sleepGoalHours: 8.0,
            workoutSessionsLast3Days: workouts.filter { $0.startTime >= calendar.date(byAdding: .day, value: -3, to: today)! }.count,
            daysSinceLastWorkout: 0, // Placeholder
            hrvScore: nil, // Könnte separat geholt werden
            restingHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil
        )
        
        let res = EnergyCalculator.calculate(
            lastNightSleepHours: sleepHours,
            sleepGoalHours: 8.0,
            recoveryScore: Double(rResult.score),
            stepsToday: Int(steps ?? 0),
            activeCaloriesToday: cals,
            workoutsToday: todayWorkouts.count,
            wakeUpTime: lastNightSleep?.wakeTime
        )
        
        await MainActor.run {
            self.result = res
            self.isLoading = false
        }
    }
}

// MARK: - EnergyCardLarge

struct EnergyCardLarge: View {
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var sleepEntries: [SleepEntry]

    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    
    @State private var result: EnergyResult?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 20) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let res = result {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(res.currentEnergy) / 100.0)
                        .stroke(energyColor(res.currentEnergy), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: CGFloat(res.currentEnergy))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.batteryblock.fill")
                            .foregroundColor(energyColor(res.currentEnergy))
                            .font(.caption)
                        Text("\(res.currentEnergy)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                }
                .frame(width: 90, height: 90)
                
                // Texts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tagesenergie")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Start: \(res.morningCapacity)%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                    HStack(spacing: 12) {
                        EnergyBadge(label: "Aktiv", value: res.stepsDrain, color: .red)
                        if res.workoutsCount > 0 {
                            EnergyBadge(label: "Training", value: res.workoutDrain, color: .green)
                        }
                        EnergyBadge(label: "Zeit", value: res.passiveDrain, color: .gray)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            } else {
                Spacer()
                Text("Keine Daten")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
        .onAppear {
            Task { await calculateEnergy() }
        }
    }
    
    private func detailRow(icon: String, text: String, color: Color) -> some View {
        EmptyView() // Kept just in case, but no longer used
    }
    
    private func energyColor(_ val: Int) -> Color {
        if val > 60 { return .green }
        if val > 30 { return .yellow }
        return .red
    }
    
    private func calculateEnergy() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let todayWorkouts = workouts.filter { calendar.isDateInToday($0.startTime) }
        
        let lastNightSleep = sleepEntries.first { calendar.isDate($0.wakeTime, inSameDayAs: today) || calendar.isDate($0.wakeTime, inSameDayAs: yesterday) }
        let sleepHours = lastNightSleep?.durationMinutes != nil ? lastNightSleep!.durationMinutes / 60.0 : nil
        
        let steps = try? await HealthKitService.shared.fetchSteps(for: today)
        let cals = try? await HealthKitService.shared.fetchActiveEnergyBurned(for: today)
        
        let rResult = RecoveryCalculator.calculate(
            lastNightSleepHours: sleepHours,
            sleepGoalHours: 8.0,
            workoutSessionsLast3Days: workouts.filter { $0.startTime >= calendar.date(byAdding: .day, value: -3, to: today)! }.count,
            daysSinceLastWorkout: 0,
            hrvScore: nil,
            restingHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil
        )
        
        let res = EnergyCalculator.calculate(
            lastNightSleepHours: sleepHours,
            sleepGoalHours: 8.0,
            recoveryScore: Double(rResult.score),
            stepsToday: Int(steps ?? 0),
            activeCaloriesToday: cals,
            workoutsToday: todayWorkouts.count,
            wakeUpTime: lastNightSleep?.wakeTime
        )
        
        await MainActor.run {
            self.result = res
            self.isLoading = false
        }
    }
}

struct EnergyBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) -\(value)%")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}
