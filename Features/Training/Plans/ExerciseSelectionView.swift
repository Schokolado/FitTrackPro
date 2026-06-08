import SwiftUI
import SwiftData

struct ExerciseSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let plan: TrainingPlan?
    var onSelect: ((Exercise) -> Void)? = nil
    var onExerciseAdded: ((PlanExercise) -> Void)? = nil
    
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var searchText: String = ""
    @State private var showingAddExercise = false
    
    @AppStorage("prefillExerciseHistory") private var prefillExerciseHistory = true
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            Section {
                Button(action: { showingAddExercise = true }) {
                    Label("Neue Übung erstellen", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.brand)
                }
            }
            
            let groupedExercises = Dictionary(grouping: filteredExercises, by: { $0.category })
            let sortedCategories = groupedExercises.keys.sorted()
            
            ForEach(sortedCategories, id: \.self) { category in
                Section(header: Text(category).font(.headline)) {
                    let sortedExercises = (groupedExercises[category] ?? []).sorted { ex1, ex2 in
                        let s1 = ex1.sortOrder == 0 ? 999 : ex1.sortOrder
                        let s2 = ex2.sortOrder == 0 ? 999 : ex2.sortOrder
                        if s1 != s2 { return s1 < s2 }
                        return ex1.name < ex2.name
                    }
                    ForEach(sortedExercises) { exercise in
                        Button(action: {
                            addExerciseToPlan(exercise)
                        }) {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Übung suchen...")
        .navigationTitle("Übung auswählen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            NavigationStack {
                ExerciseFormView { newExercise in
                    addExerciseToPlan(newExercise)
                }
            }
        }
    }
    
    private func addExerciseToPlan(_ exercise: Exercise) {
        if let onSelect = onSelect {
            onSelect(exercise)
            dismiss()
            return
        }
        
        if let plan = plan {
            let currentCount = plan.planExercises?.count ?? 0
            
            var targetSets = 3
            var targetReps = 10
            var targetWeight: Double? = nil
            
            if prefillExerciseHistory {
                let exerciseId = exercise.id
                let descriptor = FetchDescriptor<WorkoutSet>(
                    predicate: #Predicate { $0.exercise?.id == exerciseId && $0.isCompleted == true },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                
                if let pastSets = try? modelContext.fetch(descriptor), !pastSets.isEmpty {
                    if let lastSessionId = pastSets.first?.session?.id {
                        let setsFromLastSession = pastSets.filter { $0.session?.id == lastSessionId }
                        targetSets = max(1, setsFromLastSession.count)
                        targetReps = pastSets.first?.actualReps ?? 10
                        targetWeight = pastSets.first?.actualWeight
                    }
                }
            }
            
            let newPlanExercise = PlanExercise(
                sortOrder: currentCount,
                targetSets: targetSets,
                targetReps: targetReps,
                targetWeight: targetWeight,
                restDuration: exercise.defaultRestDuration,
                plan: plan,
                exercise: exercise
            )
            modelContext.insert(newPlanExercise)
            onExerciseAdded?(newPlanExercise)
        }
        dismiss()
    }
}
