import SwiftUI
import SwiftData

// MARK: - ExerciseLibraryView

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext

    /// Only load active (non-archived) exercises.
    @Query(
        filter: #Predicate<Exercise> { !$0.isArchived },
        sort: \Exercise.sortOrder
    ) private var activeExercises: [Exercise]

    @State private var viewModel = ExerciseLibraryViewModel()
    @State private var showingAddForm = false
    @State private var exerciseToArchive: Exercise?

    // MARK: - Derived

    private var availableCategories: [String] {
        Array(Set(activeExercises.map { $0.category })).sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter
                exerciseList
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
                NavigationStack { ExerciseFormView() }
            }
            .onAppear {
                SeedDataService.shared.seedExercisesIfNeeded(context: modelContext)
            }
            .confirmationDialog(
                archiveDialogTitle,
                isPresented: Binding(
                    get: { exerciseToArchive != nil },
                    set: { if !$0 { exerciseToArchive = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Archivieren", role: .destructive) {
                    if let ex = exerciseToArchive {
                        ExerciseService.shared.archive(ex, in: modelContext)
                    }
                    exerciseToArchive = nil
                }
                Button("Abbrechen", role: .cancel) {
                    exerciseToArchive = nil
                }
            } message: {
                Text(archiveDialogMessage)
            }
        }
    }

    // MARK: - Subviews

    private var categoryFilter: some View {
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
        .padding(.vertical, Spacing.sm)
    }

    private var exerciseList: some View {
        List {
            ForEach(viewModel.filterExercises(activeExercises)) { exercise in
                NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                            .font(.headline)
                        Text(exercise.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        exerciseToArchive = exercise
                    } label: {
                        Label("Archivieren", systemImage: "archivebox")
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText, prompt: "Übung suchen...")
    }

    // MARK: - Dialog Strings

    private var archiveDialogTitle: String {
        guard let ex = exerciseToArchive else { return "Übung archivieren?" }
        return "„\(ex.name)“ archivieren?"
    }

    private var archiveDialogMessage: String {
        guard let ex = exerciseToArchive else { return "" }
        let planCount = ExerciseService.shared.planCount(for: ex)
        let planText = planCount > 0
            ? "Die Übung wird aus \(planCount) \(planCount == 1 ? "Trainingsplan" : "Trainingsplänen") entfernt. "
            : ""
        return "\(planText)Deine bisherigen Workout-Daten bleiben erhalten."
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.brand : Color.backgroundSecondary)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
