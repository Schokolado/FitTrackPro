import SwiftUI
import SwiftData

struct WaterEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var amountML: String = ""
    @State private var timestamp: Date = Date()
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    HStack {
                        Text("Menge (ml)")
                        Spacer()
                        TextField("z.B. 250", text: $amountML)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isAmountFocused)
                    }
                    
                    DatePicker("Uhrzeit", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Wasser eintragen")
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
                    .disabled(amountML.isEmpty || Double(amountML.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
            .onAppear {
                isAmountFocused = true
            }
        }
    }
    
    private func saveEntry() {
        guard let amount = Double(amountML.replacingOccurrences(of: ",", with: ".")) else { return }
        
        let entry = WaterEntry(amountML: amount, timestamp: timestamp)
        modelContext.insert(entry)
        updateDailyLog(amount: amount, date: timestamp)
        
        Task {
            try? await HealthKitService.shared.saveWaterIntake(ml: amount, date: timestamp)
        }
        
        dismiss()
    }
    
    private func updateDailyLog(amount: Double, date: Date) {
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
