import SwiftUI
import SwiftData

struct WeightEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.healthKitAutoSync) private var healthKitAutoSync = false
    
    let entryToEdit: WeightEntry?
    
    @State private var weight: Double = 70.0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var showingDeleteConfirmation = false
    
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
                    DatePicker("Datum", selection: $date, in: ...Date(), displayedComponents: .date)
                        .onChange(of: date) { _, _ in
                            // Dismiss the popover by resigning first responder (simulates tapping outside)
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                if entryToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Eintrag löschen")
                                Spacer()
                            }
                        }
                    }
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
            .alert("Eintrag löschen?", isPresented: $showingDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    deleteEntry()
                    dismiss()
                }
            } message: {
                Text("Bist du sicher, dass du diesen Gewichtseintrag löschen möchtest? Dies kann nicht rückgängig gemacht werden.")
            }
        }
    }
    
    private func saveEntry() {
        let entryToSave: WeightEntry
        if let entry = entryToEdit {
            // Update existing
            entry.weightKg = weight
            entry.timestamp = date
            entry.notes = notes
            entryToSave = entry
        } else {
            // Create new
            let newEntry = WeightEntry(weightKg: weight, timestamp: date, notes: notes)
            modelContext.insert(newEntry)
            entryToSave = newEntry
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving weight entry: \(error)")
        }
        
        if healthKitEnabled && healthKitAutoSync {
            Task {
                do {
                    try await HealthKitService.shared.exportWeight(entry: entryToSave)
                    entryToSave.syncedToHealthKit = true
                    try? modelContext.save()
                } catch {
                    print("Error exporting weight to HealthKit: \(error)")
                }
            }
        }
        
        // TODO: Update WidgetDataService if implemented
    }
    
    private func deleteEntry() {
        if let entry = entryToEdit {
            modelContext.delete(entry)
        }
    }
}

#Preview {
    WeightEntryFormView()
}
