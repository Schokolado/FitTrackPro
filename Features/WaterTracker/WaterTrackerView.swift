import SwiftUI
import SwiftData
import Charts

enum WaterTimeRange: String, CaseIterable, Identifiable {
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"
    case all = "Gesamt"
    
    var id: Self { self }
}

struct WaterChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let amountML: Double
}

struct WaterTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var entries: [WaterEntry]
    
    @AppStorage(AppStorageKeys.dailyWaterGoalML) private var goalML: Double = 2500
    @AppStorage(AppStorageKeys.waterQuickAddPreset1) private var preset1: Double = 250
    @AppStorage(AppStorageKeys.waterQuickAddPreset2) private var preset2: Double = 500
    @AppStorage(AppStorageKeys.waterQuickAddPreset3) private var preset3: Double = 750
    
    @State private var showingAddEntry = false
    @State private var selectedTimeRange: WaterTimeRange = .week
    @State private var selectedDate: Date?
    
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
    
    var filteredEntries: [WaterEntry] {
        let now = Date()
        let calendar = Calendar.current
        
        return entries.filter { entry in
            switch selectedTimeRange {
            case .week:
                if let aWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                    return entry.timestamp >= aWeekAgo
                }
                return true
            case .month:
                if let aMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) {
                    return entry.timestamp >= aMonthAgo
                }
                return true
            case .year:
                if let aYearAgo = calendar.date(byAdding: .year, value: -1, to: now) {
                    return entry.timestamp >= aYearAgo
                }
                return true
            case .all:
                return true
            }
        }
    }
    
    var chartEntries: [WaterChartDataPoint] {
        let calendar = Calendar.current
        var groupedByDay: [Date: Double] = [:]
        
        for entry in filteredEntries {
            let day = calendar.startOfDay(for: entry.timestamp)
            groupedByDay[day, default: 0] += entry.amountML
        }
        
        return groupedByDay.map { WaterChartDataPoint(timestamp: $0.key, amountML: $0.value) }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var groupedEntries: [(String, [WaterEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        
        var grouped: [(String, [WaterEntry])] = []
        var currentGroup: String = ""
        var currentEntries: [WaterEntry] = []
        
        for entry in filteredEntries {
            let key = formatter.string(from: entry.timestamp)
            if key != currentGroup {
                if !currentEntries.isEmpty {
                    grouped.append((currentGroup, currentEntries))
                }
                currentGroup = key
                currentEntries = [entry]
            } else {
                currentEntries.append(entry)
            }
        }
        if !currentEntries.isEmpty {
            grouped.append((currentGroup, currentEntries))
        }
        
        return grouped
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Progress)
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 20)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.cyan)
                                .font(.title)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(todayAmount, format: .number.precision(.fractionLength(0)))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                Text("ml")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("von \(Int(goalML)) ml")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 220, height: 220)
                    .padding(.top, 20)
                    
                    // Quick Adds
                    HStack(spacing: 12) {
                        quickAddButton(amount: preset1)
                        quickAddButton(amount: preset2)
                        quickAddButton(amount: preset3)
                    }
                }
                
                // Time Range Picker
                if !entries.isEmpty {
                    Picker("Zeitraum", selection: $selectedTimeRange) {
                        ForEach(WaterTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Chart
                if !filteredEntries.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Verlauf (\(selectedTimeRange.rawValue))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(chartEntries) { entry in
                                BarMark(
                                    x: .value("Datum", entry.timestamp, unit: .day),
                                    y: .value("Menge", entry.amountML)
                                )
                                .foregroundStyle(Color.cyan.gradient)
                                .cornerRadius(4)
                            }
                            
                            RuleMark(y: .value("Ziel", goalML))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(Color.cyan.opacity(0.5))
                        }
                        .chartYScale(domain: 0...(max(goalML + 500, (chartEntries.map { $0.amountML }.max() ?? goalML) + 500)))
                        .frame(height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.backgroundSecondary)
                        )
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "drop")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(entries.isEmpty ? "Noch keine Daten vorhanden." : "Keine Daten in diesem Zeitraum.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                }
                
                // History List
                if !filteredEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Historie (\(selectedTimeRange.rawValue))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(groupedEntries, id: \.0) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.0)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                ForEach(group.1) { entry in
                                    WaterEntryRow(entry: entry)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteEntry(entry)
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100) // Space for FAB
            .frame(maxWidth: .infinity)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Wasser")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                showingAddEntry = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.cyan)
                    .clipShape(Circle())
                    .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showingAddEntry) {
            WaterEntryFormView()
                .presentationDetents([.fraction(0.5)])
        }
    }
    
    private func quickAddButton(amount: Double) -> some View {
        Button(action: {
            addWater(amount)
        }) {
            VStack {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text("\(Int(amount)) ml")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.cyan)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.cyan.opacity(0.15))
            .clipShape(Capsule())
        }
    }
    
    private func addWater(_ amount: Double) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let entry = WaterEntry(amountML: amount)
        modelContext.insert(entry)
        updateDailyLog(amount: amount)
        
        Task {
            try? await HealthKitService.shared.saveWaterIntake(ml: amount, date: entry.timestamp)
        }
    }
    
    private func deleteEntry(_ entry: WaterEntry) {
        let amount = entry.amountML
        let date = entry.timestamp
        // Adjust DailyLog
        updateDailyLog(amount: -amount, for: date)
        modelContext.delete(entry)
        
        Task {
            try? await HealthKitService.shared.deleteWaterIntake(ml: amount, date: date)
        }
    }
    
    private func updateDailyLog(amount: Double, for date: Date = Date()) {
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

struct WaterEntryRow: View {
    let entry: WaterEntry
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                
                Text(entry.amountML, format: .number.precision(.fractionLength(0)))
                    .font(.title3.bold())
                    + Text(" ml").font(.body).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        WaterTrackerView()
    }
}
