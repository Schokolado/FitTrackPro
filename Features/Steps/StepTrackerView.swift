import SwiftUI
import SwiftData
import Charts

struct DailyStepData: Identifiable {
    let id = UUID()
    let date: Date
    let healthKitSteps: Int
    let manualSteps: Int
    
    var totalSteps: Int {
        healthKitSteps + manualSteps
    }
}

struct StepTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("daily_step_goal") private var dailyStepGoal: Int = 10000
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    
    @Query(sort: \StepEntry.timestamp, order: .reverse) private var manualEntries: [StepEntry]
    
    @State private var dailyData: [DailyStepData] = []
    @State private var isLoading = true
    @State private var showAddEntry = false
    @State private var selectedTimeRange: TimeRange = .thirtyDays
    
    enum TimeRange: String, CaseIterable {
        case sevenDays = "7 Tage"
        case thirtyDays = "30 Tage"
        
        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time Range Picker
                Picker("Zeitraum", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTimeRange) { _ in
                    Task { await loadData() }
                }
                
                // Stats Summary
                HStack(spacing: 16) {
                    StatCard(
                        title: "Ø Schritte",
                        value: "\(averageSteps)",
                        icon: "figure.walk",
                        color: .brand
                    )
                    StatCard(
                        title: "Tage am Ziel",
                        value: "\(daysHittingGoal)/\(selectedTimeRange.days)",
                        icon: "target",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                // Chart
                VStack(alignment: .leading) {
                    Text("Schritt-Historie")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                    } else if dailyData.isEmpty {
                        ContentUnavailableView("Keine Daten", systemImage: "figure.walk", description: Text("Es wurden keine Schrittdaten für diesen Zeitraum gefunden."))
                            .frame(height: 250)
                    } else {
                        Chart {
                            RuleMark(y: .value("Ziel", dailyStepGoal))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(.green)
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Ziel: \(dailyStepGoal)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            
                            ForEach(dailyData) { data in
                                BarMark(
                                    x: .value("Datum", data.date, unit: .day),
                                    y: .value("Apple Health", data.healthKitSteps)
                                )
                                .foregroundStyle(Color.brand.gradient)
                                
                                BarMark(
                                    x: .value("Datum", data.date, unit: .day),
                                    y: .value("Manuell", data.manualSteps)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: selectedTimeRange == .sevenDays ? 1 : 5)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.day().month())
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
                
                // Legend
                HStack {
                    Circle().fill(Color.brand).frame(width: 10, height: 10)
                    Text("Apple Health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Circle().fill(Color.blue).frame(width: 10, height: 10)
                    Text("Manuell")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // List of Days
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verlauf")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(dailyData.reversed()) { data in
                        HStack {
                            Text(data.date, format: .dateTime.weekday(.wide).day().month())
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(data.totalSteps) Schritte")
                                    .font(.headline)
                                    .foregroundColor(data.totalSteps >= dailyStepGoal ? .green : .primary)
                                
                                if data.manualSteps > 0 {
                                    Text("\(data.manualSteps) manuell")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Schritte")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddEntry = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            StepEntryFormView()
        }
        .task {
            await loadData()
        }
        .onChange(of: manualEntries) { _ in
            Task { await loadData() }
        }
    }
    
    private var averageSteps: Int {
        guard !dailyData.isEmpty else { return 0 }
        let sum = dailyData.reduce(0) { $0 + $1.totalSteps }
        return sum / dailyData.count
    }
    
    private var daysHittingGoal: Int {
        dailyData.filter { $0.totalSteps >= dailyStepGoal }.count
    }
    
    private func loadData() async {
        isLoading = true
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days + 1, to: endDate) else { return }
        
        var hkData: [(date: Date, steps: Int)] = []
        if healthKitEnabled {
            do {
                hkData = try await HealthKitService.shared.fetchStepsHistory(startDate: startDate, endDate: endDate)
            } catch {
                print("Error fetching HealthKit steps: \(error)")
            }
        }
        
        var newData: [DailyStepData] = []
        
        for i in 0..<selectedTimeRange.days {
            guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let startOfDate = calendar.startOfDay(for: date)
            
            // HealthKit
            let hkSteps = hkData.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDate) })?.steps ?? 0
            
            // Manual
            let dateString = startOfDate.iso8601String()
            let manualSteps = manualEntries.filter { $0.dateString == dateString }.reduce(0) { $0 + $1.steps }
            
            newData.append(DailyStepData(date: startOfDate, healthKitSteps: hkSteps, manualSteps: manualSteps))
        }
        
        await MainActor.run {
            self.dailyData = newData
            self.isLoading = false
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
