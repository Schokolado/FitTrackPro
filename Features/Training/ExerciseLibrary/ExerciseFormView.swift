import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var externalVideoURLString: String = ""
    @State private var localMediaPaths: [String] = []
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    
    init(exerciseToEdit: Exercise? = nil, onSave: ((Exercise) -> Void)? = nil) {
        self.exerciseToEdit = exerciseToEdit
        self.onSave = onSave
        if let exercise = exerciseToEdit {
            _name = State(initialValue: exercise.name)
            _category = State(initialValue: exercise.category)
            _defaultRestDuration = State(initialValue: exercise.defaultRestDuration)
            _notes = State(initialValue: exercise.notes)
            _externalVideoURLString = State(initialValue: exercise.externalVideoURL?.absoluteString ?? "")
            _localMediaPaths = State(initialValue: exercise.localMediaPaths)
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
            
            Section(header: Text("Medien & Video")) {
                TextField("Externer Video-Link (z.B. YouTube)", text: $externalVideoURLString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                PhotosPicker(
                    selection: $selectedMediaItems,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Bilder hinzufügen", systemImage: "photo.on.rectangle.angled")
                        .foregroundColor(.brand)
                }
                .onChange(of: selectedMediaItems) { _, newItems in
                    loadMediaItems(newItems)
                    selectedMediaItems.removeAll() // Reset selection after picking
                }
                
                if !localMediaPaths.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(localMediaPaths, id: \.self) { path in
                                ZStack(alignment: .topTrailing) {
                                    if let image = MediaStorageService.shared.loadImage(named: path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                    }
                                    
                                    Button(action: {
                                        deleteMedia(path)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
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
        
        let videoURL = URL(string: externalVideoURLString.trimmingCharacters(in: .whitespaces))
        
        if let exercise = exerciseToEdit {
            exercise.name = name
            exercise.category = finalCategory
            exercise.defaultRestDuration = defaultRestDuration
            exercise.notes = notes
            exercise.externalVideoURL = videoURL
            exercise.localMediaPaths = localMediaPaths
            onSave?(exercise)
        } else {
            let newExercise = Exercise(
                name: name,
                category: finalCategory,
                notes: notes,
                externalVideoURL: videoURL,
                localMediaPaths: localMediaPaths,
                defaultRestDuration: defaultRestDuration,
                isCustom: true
            )
            modelContext.insert(newExercise)
            onSave?(newExercise)
        }
        dismiss()
    }
    
    private func loadMediaItems(_ items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data?):
                        if let image = UIImage(data: data) {
                            if let fileName = MediaStorageService.shared.saveImage(image) {
                                self.localMediaPaths.append(fileName)
                            }
                        }
                    case .success(nil):
                        break
                    case .failure(let error):
                        print("Error loading image: \(error)")
                    }
                }
            }
        }
    }
    
    private func deleteMedia(_ path: String) {
        localMediaPaths.removeAll { $0 == path }
        MediaStorageService.shared.deleteMedia(named: path)
    }
}
