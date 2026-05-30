import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exerciseToEdit: Exercise?
    var onSave: ((Exercise) -> Void)?
    
    @Query private var allExercises: [Exercise]
    
    private var availableCategories: [String] {
        Array(Set(allExercises.map { $0.category })).sorted()
    }
    
    @State private var name: String = ""
    @State private var category: String = "Freie Gewichte"
    @State private var isCustomCategory: Bool = false
    @State private var customCategoryName: String = ""
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
                
                if !isCustomCategory {
                    Picker("Kategorie", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Divider()
                        Text("Neue Kategorie...").tag("new_custom_category_flag")
                    }
                    .onChange(of: category) { oldValue, newValue in
                        if newValue == "new_custom_category_flag" {
                            isCustomCategory = true
                            category = availableCategories.first ?? "Freie Gewichte"
                        }
                    }
                }
                
                if isCustomCategory {
                    HStack {
                        TextField("Neue Kategorie", text: $customCategoryName)
                        Button(action: {
                            isCustomCategory = false
                            customCategoryName = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
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
        let finalCategory = isCustomCategory && !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty ? customCategoryName : category
        
        if let exercise = exerciseToEdit {
            exercise.name = name
            exercise.category = finalCategory
            exercise.defaultRestDuration = defaultRestDuration
            exercise.notes = notes
            onSave?(exercise)
        } else {
            let newExercise = Exercise(
                name: name,
                category: finalCategory,
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
