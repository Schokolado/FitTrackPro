import SwiftUI
import SwiftData

struct SleepEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var bedTime: Date = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date().addingTimeInterval(-86400)) ?? Date()
    @State private var wakeTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var quality: SleepQuality = .good
    
    var durationMinutes: Double {
        let diff = wakeTime.timeIntervalSince(bedTime)
        return max(0, diff / 60.0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Zeiten")) {
                    DatePicker("Einschlafzeit", selection: $bedTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Aufwachzeit", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Dauer")
                        Spacer()
                        let hours = Int(durationMinutes) / 60
                        let minutes = Int(durationMinutes) % 60
                        Text("\(hours)h \(minutes)m")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Qualität")) {
                    Picker("Bewertung", selection: $quality) {
                        ForEach(SleepQuality.allCases, id: \.self) { q in
                            Text(q.displayName).tag(q)
                        }
                    }
                }
            }
            .navigationTitle("Schlaf nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveEntry()
                    }
                    .disabled(durationMinutes <= 0)
                }
            }
        }
    }
    
    private func saveEntry() {
        let entry = SleepEntry(
            bedTime: bedTime,
            wakeTime: wakeTime,
            durationMinutes: durationMinutes,
            quality: quality,
            source: "Manuell"
        )
        
        modelContext.insert(entry)
        
        Task {
            try? await HealthKitService.shared.saveSleep(bedTime: bedTime, wakeTime: wakeTime)
        }
        
        dismiss()
    }
}
