import SwiftUI
import SwiftData
import Charts

enum WeightTimeRange: String, CaseIterable, Identifiable {
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"
    case all = "Gesamt"
    
    var id: Self { self }
}

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    
    @State private var showingAddEntry = false
    @State private var entryToEdit: WeightEntry?
    @State private var selectedTimeRange: WeightTimeRange = .month // Default to month
    
    var filteredEntries: [WeightEntry] {
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
    
    var groupedEntries: [(String, [WeightEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        
        var grouped: [(String, [WeightEntry])] = []
        var currentGroup: String = ""
        var currentEntries: [WeightEntry] = []
        
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
    
    var chartYScale: ClosedRange<Double> {
        let weights = filteredEntries.map { $0.weightKg }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100
        
        if minWeight == maxWeight {
            return (minWeight - 5)...(maxWeight + 5)
        }
        
        let padding = (maxWeight - minWeight) * 0.1
        return (minWeight - padding)...(maxWeight + padding)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Current Weight based on filtered entries)
                VStack(spacing: 8) {
                    Text("Aktuelles Gewicht")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let latest = entries.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(latest.weightKg, format: .number.precision(.fractionLength(1)))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("kg")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        if filteredEntries.count > 1 {
                            let previous = filteredEntries[1]
                            let diff = latest.weightKg - previous.weightKg
                            
                            HStack(spacing: 4) {
                                Image(systemName: diff > 0 ? "arrow.up.right" : (diff < 0 ? "arrow.down.right" : "arrow.right"))
                                Text(abs(diff), format: .number.precision(.fractionLength(1)))
                                Text("kg")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(diff > 0 ? .red : (diff < 0 ? .green : .secondary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(diff > 0 ? Color.red.opacity(0.15) : (diff < 0 ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15)))
                            )
                        }
                    } else {
                        Text("-- kg")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                }
                .padding(.top, 20)
                
                // Time Range Picker
                if !entries.isEmpty {
                    Picker("Zeitraum", selection: $selectedTimeRange) {
                        ForEach(WeightTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Chart
                if filteredEntries.count > 1 {
                    VStack(alignment: .leading) {
                        Text("Verlauf (\(selectedTimeRange.rawValue))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(filteredEntries.reversed()) { entry in
                                LineMark(
                                    x: .value("Datum", entry.timestamp),
                                    y: .value("Gewicht", entry.weightKg)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.brand)
                                
                                AreaMark(
                                    x: .value("Datum", entry.timestamp),
                                    yStart: .value("Base", chartYScale.lowerBound),
                                    yEnd: .value("Gewicht", entry.weightKg)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.brand.opacity(0.3), Color.brand.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                
                                PointMark(
                                    x: .value("Datum", entry.timestamp),
                                    y: .value("Gewicht", entry.weightKg)
                                )
                                .foregroundStyle(Color.brand)
                            }
                        }
                        .chartYScale(domain: chartYScale)
                        .clipped()
                        .frame(height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.backgroundSecondary)
                        )
                        .padding(.horizontal)
                    }
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Noch keine Daten vorhanden.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else if filteredEntries.count <= 1 {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Nicht genug Daten für diesen Zeitraum.")
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
                                    WeightEntryRow(entry: entry)
                                        .onTapGesture {
                                            entryToEdit = entry
                                        }
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
        .navigationTitle("Gewicht")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                showingAddEntry = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.brand)
                    .clipShape(Circle())
                    .shadow(color: .brand.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showingAddEntry) {
            WeightEntryFormView()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $entryToEdit) { entry in
            WeightEntryFormView(entryToEdit: entry)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func deleteEntry(_ entry: WeightEntry) {
        modelContext.delete(entry)
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.weightKg, format: .number.precision(.fractionLength(1)))
                    .font(.title3.bold())
                    + Text(" kg").font(.body).foregroundColor(.secondary)
                
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(entry.timestamp, format: .dateTime.day().month().year())
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
        WeightTrackerView()
    }
}
