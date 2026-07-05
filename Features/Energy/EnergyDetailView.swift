import SwiftUI

import SwiftUI
import SwiftData

struct EnergyDetailView: View {
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var sleepEntries: [SleepEntry]

    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var workouts: [WorkoutSession]
    
    @State private var result: EnergyResult?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(minHeight: 300)
            } else if let result = result {
                VStack(spacing: 32) {
                // Header Circular Progress
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 18)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(result.currentEnergy) / 100.0)
                            .stroke(energyColor(result.currentEnergy), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: CGFloat(result.currentEnergy))
                        
                        VStack(spacing: 4) {
                            Text("\(result.currentEnergy)%")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(energyColor(result.currentEnergy))
                            
                            Text("Verbleibend")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    .padding(.top, 20)
                }
                
                // Details
                VStack(spacing: 16) {
                    Text("Dein Tag")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    detailBox(
                        title: "Startkapazität",
                        value: "\(result.morningCapacity)%",
                        subtitle: "Aus \(result.sleepPoints)% Schlaf & \(result.recoveryPoints)% Recovery",
                        icon: "sunrise.fill",
                        color: .orange
                    )
                    
                    if let cal = result.activeCaloriesBurned {
                        detailBox(
                            title: "Aktivitätskalorien",
                            value: "-\(result.stepsDrain)%",
                            subtitle: "\(Int(cal)) kcal verbrannt",
                            icon: "flame.fill",
                            color: .red
                        )
                    } else {
                        detailBox(
                            title: "Alltagsaktivität",
                            value: "-\(result.stepsDrain)%",
                            subtitle: "\(result.steps) Schritte",
                            icon: "figure.walk",
                            color: .blue
                        )
                    }
                    
                    detailBox(
                        title: "Training",
                        value: "-\(result.workoutDrain)%",
                        subtitle: "\(result.workoutsCount) Workout(s) absolviert",
                        icon: "figure.run",
                        color: .green
                    )
                    
                    detailBox(
                        title: "Passiver Verbrauch",
                        value: "-\(result.passiveDrain)%",
                        subtitle: "Verbrauch seit dem Aufwachen",
                        icon: "clock.fill",
                        color: .gray
                    )
                }
                .padding(.horizontal)
                
                // Recommendation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Tipp für dich")
                            .font(.headline)
                    }
                    
                    Text(recommendationText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.1)))
                .padding(.horizontal)
                } // End of VStack(spacing: 32)
            } else {
                Text("Keine Daten verfügbar")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Tagesenergie")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await calculateEnergy() }
        }
    }
    
    private func energyColor(_ val: Int) -> Color {
        if val > 60 { return .green }
        if val > 30 { return .yellow }
        return .red
    }
    
    private func detailBox(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: icon).foregroundColor(color).font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(value.starts(with: "-") ? .primary : .green)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.backgroundSecondary))
    }
    
    
    private var recommendationText: String {
        guard let res = result else { return "" }
        if res.currentEnergy > 60 {
            return "Dein Akku ist voll genug für intensive Aktivitäten. Nutze die Energie für ein Workout!"
        } else if res.currentEnergy > 30 {
            return "Dein Akku geht langsam zur Neige. Ein leichtes Workout oder ein Spaziergang sind noch drin, aber übernimm dich nicht."
        } else {
            return "Dein Akku ist fast leer. Gönn dir heute Ruhe und plane kein anstrengendes Training mehr ein."
        }
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
