import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    
    @State private var viewModel = ExerciseLibraryViewModel()
    @State private var showingAddForm = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Alle", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.selectedCategory = nil
                        }
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            FilterChip(title: category.rawValue, isSelected: viewModel.selectedCategory == category) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                List {
                    ForEach(viewModel.filterExercises(allExercises)) { exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text(exercise.category.rawValue)
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
