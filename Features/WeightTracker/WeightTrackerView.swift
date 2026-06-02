import SwiftUI
import SwiftData
import Charts

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var entries: [WeightEntry]
    
    @State private var showingAddEntry = false
    @State private var entryToEdit: WeightEntry?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Current Weight)
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
                        
                        if entries.count > 1 {
                            let previous = entries[1]
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
                
                // Chart
                if entries.count > 1 {
                    VStack(alignment: .leading) {
                        Text("Verlauf")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            // Reverse entries so the chart goes left to right chronologically
                            ForEach(entries.reversed()) { entry in
                                LineMark(
                                    x: .value("Datum", entry.timestamp),
                                    y: .value("Gewicht", entry.weightKg)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.brand)
                                
                                AreaMark(
                                    x: .value("Datum", entry.timestamp),
                                    y: .value("Gewicht", entry.weightKg)
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
                        .chartYScale(domain: .automatic(includesZero: false))
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
                }
                
                // History List
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Historie")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(entries) { entry in
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
            .padding(.bottom, 100) // Space for FAB
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
