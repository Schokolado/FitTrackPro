import SwiftUI
import SwiftData

struct WeightEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let entryToEdit: WeightEntry?
    
    @State private var weight: Double = 70.0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    init(entryToEdit: WeightEntry? = nil) {
        self.entryToEdit = entryToEdit
        
        // Initialize state with existing entry if editing
        if let entry = entryToEdit {
            _weight = State(initialValue: entry.weightKg)
            _date = State(initialValue: entry.timestamp)
            _notes = State(initialValue: entry.notes)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Gewicht (kg)")
                        Spacer()
                        TextField("0.0", value: $weight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.brand)
                            .font(.system(size: 22, weight: .bold))
                    }
                }
                
                Section {
                    DatePicker("Datum & Uhrzeit", selection: $date)
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(entryToEdit == nil ? "Neues Gewicht" : "Gewicht bearbeiten")
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
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
    
    private func saveEntry() {
        if let entry = entryToEdit {
            // Update existing
            entry.weightKg = weight
            entry.timestamp = date
            entry.notes = notes
        } else {
            // Create new
            let newEntry = WeightEntry(weightKg: weight, timestamp: date, notes: notes)
            modelContext.insert(newEntry)
        }
        
        // TODO: Update WidgetDataService if implemented
    }
}

#Preview {
    WeightEntryFormView()
}
