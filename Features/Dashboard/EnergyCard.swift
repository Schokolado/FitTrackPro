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
        .frame(height: 160)
        .padding(16)
        .background(Color.backgroundSecondary)
        .cornerRadius(20)
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
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    Text("Tagesenergie")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Content
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let res = result {
                HStack(spacing: 20) {
                    // Ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(res.currentEnergy) / 100.0)
                            .stroke(energyColor(res.currentEnergy), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(res.currentEnergy)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(energyColor(res.currentEnergy))
                    }
                    .frame(width: 80, height: 80)
                    
                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        detailRow(icon: "sunrise.fill", text: "Start: \(res.morningCapacity)%", color: .orange)
                        if res.activeCaloriesBurned != nil {
                            detailRow(icon: "flame.fill", text: "Aktiv: -\(res.stepsDrain)%", color: .red)
                        } else {
                            detailRow(icon: "figure.walk", text: "Schritte: -\(res.stepsDrain)%", color: .blue)
                        }
                        if res.workoutsCount > 0 {
                            detailRow(icon: "figure.run", text: "Training: -\(res.workoutDrain)%", color: .green)
                        }
                        detailRow(icon: "clock.fill", text: "Zeit: -\(res.passiveDrain)%", color: .gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                Spacer()
                Text("Keine Daten")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(height: 130)
        .background(Color.backgroundSecondary)
        .cornerRadius(20)
        .onAppear {
            Task { await calculateEnergy() }
        }
    }
    
    private func detailRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
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
