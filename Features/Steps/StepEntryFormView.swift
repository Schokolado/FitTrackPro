import SwiftUI
import SwiftData

struct StepEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var stepsText: String = ""
    @State private var date: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Schritte erfassen"), footer: Text("Trage hier Schritte ein, wenn du dein Handy nicht bei dir hattest oder sie manuell trackst.")) {
                    TextField("Anzahl Schritte", text: $stepsText)
                        .keyboardType(.numberPad)
                    
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Schritte eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveEntry()
                    }
                    .disabled(Int(stepsText) == nil || Int(stepsText)! <= 0)
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let steps = Int(stepsText), steps > 0 else { return }
        
        let newEntry = StepEntry(steps: steps, date: date, isManual: true)
        modelContext.insert(newEntry)
        
        try? modelContext.save()
        dismiss()
    }
}
