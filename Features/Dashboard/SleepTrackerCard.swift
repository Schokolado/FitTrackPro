import SwiftUI
import SwiftData

struct SleepTrackerCard: View {
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var manualEntries: [SleepEntry]
    @AppStorage(AppStorageKeys.dailySleepGoalHours) private var sleepGoalHours: Double = 8.0
    
    @State private var hkLastNight: (Date, Double)?
    @State private var previousDurationMinutes: Double = 0
    @State private var isLoading = true
    
    var durationMinutes: Double {
        if let hk = hkLastNight {
            return hk.1
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
            return Calendar.current.isDateInYesterday(hk.0) || Calendar.current.isDate(hk.0, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        } else if let manual = manualEntries.first {
            return Calendar.current.isDateInYesterday(manual.wakeTime)
        }
        return false
    }
    
    var hours: Int { Int(durationMinutes) / 60 }
    var minutes: Int { Int(durationMinutes) % 60 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Schlaf")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
                    if isYesterdayData {
                        HStack(spacing: 4) {
                            Text("Gestern")
                        }
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
            isLoading = true
            do {
                let today = Date()
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
                let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
                
                if let data = try await HealthKitService.shared.fetchSleepData(for: today), data.totalDurationMinutes > 0 {
                    hkLastNight = (data.wakeTime ?? today, data.totalDurationMinutes)
                    if let prev = try await HealthKitService.shared.fetchSleepData(for: yesterday) {
                        previousDurationMinutes = prev.totalDurationMinutes
                    }
                } else {
                    // Fallback to yesterday
                    if let data = try await HealthKitService.shared.fetchSleepData(for: yesterday), data.totalDurationMinutes > 0 {
                        hkLastNight = (data.wakeTime ?? yesterday, data.totalDurationMinutes)
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
