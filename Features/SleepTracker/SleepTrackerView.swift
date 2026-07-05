import SwiftUI
import SwiftData
import Charts

struct SleepChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let durationHours: Double
    let source: String
    let phases: SleepDaySummary?
}

struct SleepTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepEntry.wakeTime, order: .reverse) private var manualEntries: [SleepEntry]
    
    @AppStorage(AppStorageKeys.dailySleepGoalHours) private var sleepGoalHours: Double = 8.0
    
    @State private var showingAddEntry = false
    @State private var expandedGroups: Set<String> = []
    @State private var selectedTimeRange: WaterTimeRange = .week // Reuse TimeRange enum
    @State private var selectedMonthForChart: String? = nil
    @State private var healthKitSleep: [SleepDaySummary] = []
    @State private var isLoadingHealthKit = true
    @State private var selectedDate: Date?
    
    // Combine HealthKit and Manual Entries, aggregated per day
    var allEntries: [SleepChartDataPoint] {
        let calendar = Calendar.current
        var manualDurations: [Date: Double] = [:]
        
        // Add manual entries
        for entry in manualEntries {
            let day = calendar.startOfDay(for: entry.wakeTime)
            manualDurations[day, default: 0.0] += (entry.durationMinutes / 60.0)
        }
        
        var combined: [SleepChartDataPoint] = []
        for (day, duration) in manualDurations {
            combined.append(SleepChartDataPoint(
                date: day,
                durationHours: duration,
                source: "Manuell",
                phases: nil
            ))
        }
        
        // Add HealthKit entries
        var hkDurations: [Date: SleepDaySummary] = [:]
        for hk in healthKitSleep {
            let hkDay = calendar.startOfDay(for: hk.date)
            // Only use HealthKit if there are no manual entries for this day
            if manualDurations[hkDay] == nil {
                hkDurations[hkDay] = hk // Keep the last/only summary for the day (HealthKitService already aggregates per day for us)
            }
        }
        
        for (day, summary) in hkDurations {
            combined.append(SleepChartDataPoint(
                date: day,
                durationHours: summary.totalDurationMinutes / 60.0,
                source: "HealthKit",
                phases: summary // hkDurations should hold the SleepDaySummary
            ))
        }
        
        return combined.sorted { $0.date > $1.date }
    }
    
    var groupedEntries: [(String, [SleepChartDataPoint])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        
        var grouped: [(String, [SleepChartDataPoint])] = []
        var currentGroup: String = ""
        var currentEntries: [SleepChartDataPoint] = []
        
        for entry in allEntries {
            let key = formatter.string(from: entry.date)
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
    
    var lastNight: SleepChartDataPoint? {
        allEntries.first
    }
    
    var chartEntries: [SleepChartDataPoint] {
        if let month = selectedMonthForChart {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            formatter.locale = Locale(identifier: "de_DE")
            return allEntries.filter { formatter.string(from: $0.date) == month }.sorted { $0.date < $1.date }
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        let filtered = allEntries.filter { entry in
            switch selectedTimeRange {
            case .week:
                return entry.date >= calendar.date(byAdding: .day, value: -7, to: now)!
            case .month:
                return entry.date >= calendar.date(byAdding: .month, value: -1, to: now)!
            case .year:
                return entry.date >= calendar.date(byAdding: .year, value: -1, to: now)!
            case .all:
                return true
            }
        }
        
        return filtered.sorted { $0.date < $1.date }
    }
    
    var avgDuration: Double {
        guard !chartEntries.isEmpty else { return 0 }
        let total = chartEntries.reduce(0) { $0 + $1.durationHours }
        return total / Double(chartEntries.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Last Night)
                VStack(spacing: 8) {
                    Text("Letzte Nacht")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let last = lastNight {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            let hours = Int(last.durationHours)
                            let minutes = Int((last.durationHours - Double(hours)) * 60)
                            
                            Text("\(hours)h \(minutes)m")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(last.durationHours >= sleepGoalHours ? .green : .orange)
                        }
                    } else if isLoadingHealthKit {
                        ProgressView()
                            .padding()
                    } else {
                        Text("--h --m")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                }
                .padding(.top, 20)
                
                // Time Range
                Picker("Zeitraum", selection: $selectedTimeRange) {
                    ForEach(WaterTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Chart
                if !chartEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Verlauf (\(selectedMonthForChart ?? selectedTimeRange.rawValue))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(chartEntries) { entry in
                                let isSelected = selectedDate == nil || Calendar.current.isDate(entry.date, inSameDayAs: selectedDate!)
                                
                                BarMark(
                                    x: .value("Datum", entry.date, unit: .day),
                                    y: .value("Stunden", entry.durationHours)
                                )
                                .foregroundStyle(entry.durationHours >= sleepGoalHours ? Color.green.gradient : Color.orange.gradient)
                                .opacity(isSelected ? 1.0 : 0.3)
                                .cornerRadius(4)
                            }
                            
                            RuleMark(y: .value("Ziel", sleepGoalHours))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .annotation(position: .trailing, alignment: .leading) {
                                    Text("Ziel: \(Int(sleepGoalHours))h")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                
                            if let selected = selectedDate, let entry = chartEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                                RuleMark(
                                    x: .value("Datum", entry.date, unit: .day)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(Color.secondary)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                    let hours = Int(entry.durationHours)
                                    let minutes = Int((entry.durationHours - Double(hours)) * 60)
                                    VStack(alignment: .center, spacing: 2) {
                                        Text("\(hours)h \(minutes)m")
                                            .font(.caption.bold())
                                        Text(entry.date, format: .dateTime.weekday().day().month())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(uiColor: .systemBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                    )
                                }
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle().fill(.clear).contentShape(Rectangle())
                                    .onTapGesture { location in
                                        if let plotFrame = proxy.plotFrame {
                                            let origin = geometry[plotFrame]
                                            let xPosition = location.x - origin.minX
                                            if let date = proxy.value(atX: xPosition, as: Date.self) {
                                                if let entry = chartEntries.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    if selectedDate != nil && Calendar.current.isDate(entry.date, inSameDayAs: selectedDate!) {
                                                        selectedDate = nil
                                                    } else {
                                                        selectedDate = entry.date
                                                    }
                                                }
                                            } else {
                                                selectedDate = nil
                                            }
                                        }
                                    }
                            }
                        }
                        .chartYScale(domain: 0...(max(sleepGoalHours + 2, (chartEntries.map { $0.durationHours }.max() ?? sleepGoalHours) + 2)))
                        .frame(height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.backgroundSecondary)
                        )
                        .padding(.horizontal)
                        
                        // Stats
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Ø Schlafdauer")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                let avgH = Int(avgDuration)
                                let avgM = Int((avgDuration - Double(avgH)) * 60)
                                Text("\(avgH)h \(avgM)m")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                } else if !isLoadingHealthKit {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Keine Schlafdaten in diesem Zeitraum.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                }
                
                // History List
                if !allEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Historie")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(groupedEntries, id: \.0) { group in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedGroups.contains(group.0) },
                                    set: { isExpanded in
                                        withAnimation {
                                            if isExpanded {
                                                expandedGroups.insert(group.0)
                                                selectedMonthForChart = group.0
                                            } else {
                                                expandedGroups.remove(group.0)
                                                if selectedMonthForChart == group.0 {
                                                    selectedMonthForChart = nil
                                                }
                                            }
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(group.1) { entry in
                                        NavigationLink(destination: SleepDetailView(entry: entry)) {
                                            SleepEntryRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            if entry.source == "Manuell" {
                                                Button(role: .destructive) {
                                                    let toDelete = manualEntries.filter { Calendar.current.isDate($0.wakeTime, inSameDayAs: entry.date) }
                                                    for m in toDelete {
                                                        modelContext.delete(m)
                                                    }
                                                } label: {
                                                    Label("Löschen", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            } label: {
                                Text(group.0)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.backgroundSecondary)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedDate != nil {
                            selectedDate = nil
                        }
                    }
            )
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Schlaf")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                showingAddEntry = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.indigo)
                    .clipShape(Circle())
                    .shadow(color: .indigo.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showingAddEntry) {
            SleepEntryFormView()
                .presentationDetents([.fraction(0.6)])
        }
        .task {
            await fetchHealthKitData()
        }
    }
    
    private func fetchHealthKitData() async {
        isLoadingHealthKit = true
        defer { isLoadingHealthKit = false }
        
        do {
            let history = try await HealthKitService.shared.fetchSleepHistory(days: 90)
            self.healthKitSleep = history.filter { $0.totalDurationMinutes > 0 }
        } catch {
            print("Failed to fetch HealthKit sleep: \(error)")
        }
    }
}

struct SleepEntryRow: View {
    let entry: SleepChartDataPoint
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                let hours = Int(entry.durationHours)
                let minutes = Int((entry.durationHours - Double(hours)) * 60)
                
                Text("\(hours)h \(minutes)m")
                    .font(.title3.bold())
            }
            
            Spacer()
            
            Text(entry.date, format: .dateTime.weekday().day().month())
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
        SleepTrackerView()
    }
}
