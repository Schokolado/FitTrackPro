import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    
    private var availableCategories: [String] {
        Array(Set(allExercises.map { $0.category })).sorted()
    }
    
    @State private var viewModel = ExerciseLibraryViewModel()
    @State private var showingAddForm = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category Filter Dropdown
                HStack {
                    Text("Kategorie:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Kategorie", selection: $viewModel.selectedCategory) {
                        Text("Alle").tag(String?.none)
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(String?(category))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                List {
                    ForEach(viewModel.filterExercises(allExercises)) { exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text(exercise.category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.searchText, prompt: "Übung suchen...")
            }
            .navigationTitle("Übungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                NavigationStack {
                    ExerciseFormView()
                }
            }
            .onAppear {
                SeedDataService.shared.seedExercisesIfNeeded(context: modelContext)
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        let filtered = viewModel.filterExercises(allExercises)
        for index in offsets {
            let exercise = filtered[index]
            modelContext.delete(exercise)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brand : Color.backgroundSecondary)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
