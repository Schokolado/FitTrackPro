import SwiftUI
import SwiftData
import Charts

// MARK: - WeightSummaryCardLarge

struct WeightSummaryCardLarge: View {
    let entries: [WeightEntry]

    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.2))

                Image(systemName: "scalemass")
                    .foregroundColor(.brand)
                    .font(.title)
            }
            .frame(width: 60, height: 60)

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text("Gewicht")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let latest = entries.first {
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(latest.weightKg, specifier: "%.1f") kg")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .fixedSize()

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
                        }

                        if entries.count > 2 {
                            let chartData = Array(entries.prefix(7).reversed())
                            let minWeight = chartData.map { $0.weightKg }.min() ?? 0
                            let maxWeight = chartData.map { $0.weightKg }.max() ?? 100

                            Chart {
                                ForEach(chartData) { entry in
                                    LineMark(
                                        x: .value("Datum", entry.timestamp),
                                        y: .value("Gewicht", entry.weightKg)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.brand.gradient)

                                    AreaMark(
                                        x: .value("Datum", entry.timestamp),
                                        yStart: .value("Min", minWeight - 2),
                                        yEnd: .value("Gewicht", entry.weightKg)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(LinearGradient(colors: [Color.brand.opacity(0.3), Color.brand.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .chartYScale(domain: (minWeight - 2)...(maxWeight + 2))
                            .frame(height: 50)
                            .padding(.leading, 8)
                        }
                    }
                } else {
                    Text("-- kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
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
    }
}

// MARK: - TrainingSummaryCardLarge

struct TrainingSummaryCardLarge: View {
    let workouts: [WorkoutSession]
    var activeSession: WorkoutSession? = nil
    var lastWorkout: WorkoutSession? = nil

    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))

                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.title)
            }
            .frame(width: 60, height: 60)

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text("Training heute")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let active = activeSession {
                    Text("Laufend")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.brand)
                    Text(active.plan?.name ?? "Freies Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if workouts.count > 1 {
                    Text("\(workouts.count) Erledigt")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Historie ansehen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let workout = workouts.first {
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
                    if let last = lastWorkout {
                        Text("\(formatLastWorkoutDate(last.startTime)): \(last.plan?.name ?? "Freies Workout")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Tippen zum Starten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    }

    private func formatLastWorkoutDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return "Gestern"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM."
            return formatter.string(from: date)
        }
    }
}

// MARK: - WaterTrackerCardLarge

struct WaterTrackerCardLarge: View {
    let entries: [WaterEntry]
    @AppStorage(AppStorageKeys.dailyWaterGoalML) private var goalML: Double = 2500
    @AppStorage(AppStorageKeys.waterQuickAddPreset1) private var preset1: Double = 250
    @AppStorage(AppStorageKeys.waterQuickAddPreset2) private var preset2: Double = 500
    @AppStorage(AppStorageKeys.waterQuickAddPreset3) private var preset3: Double = 750

    @Environment(\.modelContext) private var modelContext
    @State private var splashTrigger: Int = 0

    var todayEntries: [WaterEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.timestamp) }
    }

    var todayAmount: Double {
        todayEntries.reduce(0) { $0 + $1.amountML }
    }

    var progress: Double {
        min(todayAmount / max(goalML, 1), 1.0)
    }

    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                VStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.cyan)
                        .font(.caption)
                        .symbolEffect(.bounce, options: .speed(1.2), value: splashTrigger)
                    Text("\(Int(todayAmount))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: 90, height: 90)

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text("Wasser heute")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Int(max(goalML - todayAmount, 0))) ml verbleibend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Quick Add Row
                HStack(spacing: 8) {
                    quickAddButton(amount: preset1)
                    quickAddButton(amount: preset2)
                    quickAddButton(amount: preset3)
                }
                .padding(.top, 4)
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
    }

    private func quickAddButton(amount: Double) -> some View {
        Button(action: {
            addWater(amount)
        }) {
            Text("+\(Int(amount))")
                .font(.caption.bold())
                .foregroundColor(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func addWater(_ amount: Double) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        splashTrigger += 1
        
        let entry = WaterEntry(amountML: amount)
        modelContext.insert(entry)
        updateDailyLog(amount: amount)

        Task {
            try? await HealthKitService.shared.saveWaterIntake(ml: amount, date: entry.timestamp)
        }
    }

    private func updateDailyLog(amount: Double, date: Date = Date()) {
        let todayStr = date.iso8601String()

        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dateString == todayStr })
        do {
            let logs = try modelContext.fetch(descriptor)
            if let todayLog = logs.first {
                todayLog.addWater(amount)
            } else {
                let newLog = DailyLog(dateString: todayStr, waterIntakeML: max(0, amount))
                modelContext.insert(newLog)
            }
        } catch {
            print("Error fetching DailyLog: \(error)")
        }
    }
}

// MARK: - SleepTrackerCardLarge

struct SleepTrackerCardLarge: View {
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var manualEntries: [SleepEntry]
    @AppStorage(AppStorageKeys.dailySleepGoalHours) private var sleepGoalHours: Double = 8.0

    @State private var hkLastNight: SleepDaySummary?
    @State private var previousDurationMinutes: Double = 0
    @State private var isLoading = true

    var durationMinutes: Double {
        if let hk = hkLastNight {
            return hk.totalDurationMinutes
        } else if let manual = manualEntries.first, Calendar.current.isDateInToday(manual.wakeTime) || Calendar.current.isDateInYesterday(manual.wakeTime) {
            return manual.durationMinutes
        }
        return 0
    }

    var prevDurationMinutes: Double {
        if hkLastNight != nil {
            return previousDurationMinutes
        }
        if manualEntries.count > 1 {
            return manualEntries[1].durationMinutes
        }
        return 0
    }

    var isYesterdayData: Bool {
        if let hk = hkLastNight {
            return Calendar.current.isDateInYesterday(hk.date) || Calendar.current.isDate(hk.date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        } else if let manual = manualEntries.first {
            return Calendar.current.isDateInYesterday(manual.wakeTime)
        }
        return false
    }

    var hours: Int { Int(durationMinutes) / 60 }
    var minutes: Int { Int(durationMinutes) % 60 }

    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.2))

                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
                    .font(.title)
            }
            .frame(width: 60, height: 60)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Schlaf")
                    .font(.headline)
                    .foregroundColor(.primary)

                if isLoading {
                    ProgressView()
                } else if durationMinutes > 0 {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(hours)h \(minutes)m")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor((durationMinutes / 60.0) >= sleepGoalHours ? .green : .primary)
                        
                        if prevDurationMinutes > 0 {
                            let diff = round(durationMinutes - prevDurationMinutes)
                            if diff != 0 {
                                let diffHours = abs(Int(diff)) / 60
                                let diffMinutes = abs(Int(diff)) % 60
                                let color: Color = diff > 0 ? .green : .orange
                                let sign = diff > 0 ? "+" : "-"
                                Text("\(sign)\(diffHours)h \(diffMinutes)m")
                                    .font(.caption.bold())
                                    .foregroundColor(color)
                                    .padding(.bottom, 4)
                            } else {
                                Text("±0h 0m")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                            }
                        }
                    }
                    
                    if let hk = hkLastNight {
                        HStack(spacing: 8) {
                            if hk.deepMinutes > 0 {
                                Label("\(Int(hk.deepMinutes / 60))h \(Int(hk.deepMinutes) % 60)m Tief", systemImage: "moon.stars.fill")
                                    .font(.caption2)
                                    .foregroundColor(.indigo)
                            } else {
                                if isYesterdayData {
                                    Text("Gestern")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 2)
                    } else if isYesterdayData {
                        Text("Gestern")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("--h --m")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Keine Daten")
                        .font(.caption)
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
            isLoading = true
            do {
                let today = Date()
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
                let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
                
                if let data = try await HealthKitService.shared.fetchSleepData(for: today), data.totalDurationMinutes > 0 {
                    hkLastNight = data
                    if let prev = try await HealthKitService.shared.fetchSleepData(for: yesterday) {
                        previousDurationMinutes = prev.totalDurationMinutes
                    }
                } else {
                    if let data = try await HealthKitService.shared.fetchSleepData(for: yesterday), data.totalDurationMinutes > 0 {
                        hkLastNight = data
                        if let prev = try await HealthKitService.shared.fetchSleepData(for: twoDaysAgo) {
                            previousDurationMinutes = prev.totalDurationMinutes
                        }
                    }
                }
            } catch {
                print("Error fetching sleep: \(error)")
            }
            isLoading = false
        }
    }
}
