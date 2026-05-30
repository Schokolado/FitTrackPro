import SwiftUI
import SwiftData

struct TrainingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlan.sortOrder) private var plans: [TrainingPlan]
    
    @State private var showingAddAlert = false
    @State private var newPlanName = ""
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name)
                                .font(.headline)
                            Text("\(plan.planExercises?.count ?? 0) Übungen")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            withAnimation {
                                editMode = .active
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(plan)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        
                        Button {
                            duplicate(plan: plan)
                        } label: {
                            Label("Duplizieren", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
                .onMove(perform: movePlan)
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .navigationTitle("Trainingspläne")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        newPlanName = ""
                        showingAddAlert = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        NavigationLink(destination: ExerciseLibraryView()) {
                            Image(systemName: "book.pages")
                        }
                        EditButton()
                    }
                }
            }
            .alert("Neuer Trainingsplan", isPresented: $showingAddAlert) {
                TextField("Name", text: $newPlanName)
                Button("Abbrechen", role: .cancel) { }
                Button("Erstellen") {
                    createPlan()
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .overlay {
                if plans.isEmpty {
                    ContentUnavailableView("Keine Pläne", systemImage: "list.clipboard", description: Text("Erstelle deinen ersten Trainingsplan."))
                }
            }
        }
    }
    
    private func createPlan() {
        let plan = TrainingPlan(name: newPlanName, sortOrder: plans.count)
        modelContext.insert(plan)
    }
    
    private func duplicate(plan: TrainingPlan) {
        let newPlan = TrainingPlan(name: "\(plan.name) (Kopie)", sortOrder: plans.count)
        modelContext.insert(newPlan)
        // Copy exercises
        if let exercises = plan.planExercises {
            for (index, planEx) in exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
                let newEx = PlanExercise(
                    sortOrder: index,
                    supersetGroup: planEx.supersetGroup,
                    targetSets: planEx.targetSets,
                    targetReps: planEx.targetReps,
                    targetWeight: planEx.targetWeight,
                    restDuration: planEx.restDuration,
                    plan: newPlan,
                    exercise: planEx.exercise
                )
                modelContext.insert(newEx)
            }
        }
    }
    
    private func movePlan(from source: IndexSet, to destination: Int) {
        var revisedItems = plans
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
    }
}
