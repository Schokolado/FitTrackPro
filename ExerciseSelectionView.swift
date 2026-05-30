import SwiftUI
import SwiftData

struct ExerciseSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let plan: TrainingPlan
    
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var searchText: String = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List(filteredExercises) { exercise in
            Button(action: {
                addExerciseToPlan(exercise)
            }) {
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(exercise.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
    }
    
    private func addExerciseToPlan(_ exercise: Exercise) {
        let currentCount = plan.planExercises?.count ?? 0
        let newPlanExercise = PlanExercise(
            sortOrder: currentCount,
            targetSets: 3,
            targetReps: 10,
            restDuration: exercise.defaultRestDuration,
            plan: plan,
            exercise: exercise
        )
        modelContext.insert(newPlanExercise)
        dismiss()
    }
}
