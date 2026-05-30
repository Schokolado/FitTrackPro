import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exerciseToEdit: Exercise?
    var onSave: ((Exercise) -> Void)?
    
    @State private var name: String = ""
    @State private var category: ExerciseCategory = .freeWeight
    @State private var defaultRestDuration: Double = 90
    @State private var notes: String = ""
    
    init(exerciseToEdit: Exercise? = nil, onSave: ((Exercise) -> Void)? = nil) {
        self.exerciseToEdit = exerciseToEdit
        self.onSave = onSave
        if let exercise = exerciseToEdit {
            _name = State(initialValue: exercise.name)
            _category = State(initialValue: exercise.category)
            _defaultRestDuration = State(initialValue: exercise.defaultRestDuration)
            _notes = State(initialValue: exercise.notes)
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name der Übung", text: $name)
                
                Picker("Kategorie", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }
            
            Section(header: Text("Standard-Pause (Sekunden)")) {
                Stepper(value: $defaultRestDuration, in: 0...300, step: 10) {
                    Text("\(Int(defaultRestDuration)) s")
                }
            }
            
            Section(header: Text("Notizen")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(exerciseToEdit == nil ? "Neue Übung" : "Übung bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private func save() {
        if let exercise = exerciseToEdit {
            exercise.name = name
            exercise.category = category
            exercise.defaultRestDuration = defaultRestDuration
            exercise.notes = notes
            onSave?(exercise)
        } else {
            let newExercise = Exercise(
                name: name,
                category: category,
                notes: notes,
                defaultRestDuration: defaultRestDuration,
                isCustom: true
            )
            modelContext.insert(newExercise)
            onSave?(newExercise)
        }
        dismiss()
    }
}
