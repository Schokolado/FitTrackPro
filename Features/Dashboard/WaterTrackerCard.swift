import SwiftUI
import SwiftData

struct WaterTrackerCard: View {
    let entries: [WaterEntry]
    @AppStorage(AppStorageKeys.dailyWaterGoalML) private var goalML: Double = 2500
    @AppStorage(AppStorageKeys.waterQuickAddPreset1) private var preset1: Double = 250
    @AppStorage(AppStorageKeys.waterQuickAddPreset2) private var preset2: Double = 500
    
    @Environment(\.modelContext) private var modelContext
    
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Wasser")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(todayAmount, specifier: "%.0f") ml")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text("von \(Int(goalML)) ml")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Quick Add Row
            HStack(spacing: 8) {
                quickAddButton(amount: preset1)
                quickAddButton(amount: preset2)
            }
            .padding(.top, 4)
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
    
    private func quickAddButton(amount: Double) -> some View {
        Button(action: {
            addWater(amount)
        }) {
            Text("+\(Int(amount))")
                .font(.caption.bold())
                .foregroundColor(.cyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
        }
        // This stops the button from triggering the NavigationLink of the parent
        .buttonStyle(PlainButtonStyle())
    }
    
    private func addWater(_ amount: Double) {
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
