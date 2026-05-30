import SwiftUI
import SwiftData

struct TrainingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlan.sortOrder) private var plans: [TrainingPlan]
    
    @State private var showingAddAlert = false
    @State private var showingRenameAlert = false
    @State private var newPlanName = ""
    @State private var planToRename: TrainingPlan? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "Keine Trainingspläne",
                        systemImage: "list.clipboard",
                        description: Text("Füge einen neuen Trainingsplan über das '+' oben rechts hinzu.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            ForEach(plans) { plan in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(plan.name)
                                                    .font(.headline)
                                                    .foregroundColor(.brand)
                                                Spacer()
                                            }
                                            
                                            Text("\(plan.planExercises?.count ?? 0) Übungen")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Menu {
                                        Button {
                                            planToRename = plan
                                            newPlanName = plan.name
                                            showingRenameAlert = true
                                        } label: {
                                            Label("Umbenennen", systemImage: "pencil")
                                        }
                                        
                                        Button {
                                            duplicate(plan: plan)
                                        } label: {
                                            Label("Duplizieren", systemImage: "doc.on.doc")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            modelContext.delete(plan)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 20)
                                            .padding(.bottom, 20)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .overlay(alignment: .bottomTrailing) {
                NavigationLink(destination: ExerciseLibraryView()) {
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.brand)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                .padding(20)
            }
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
            }
            .alert("Neuer Trainingsplan", isPresented: $showingAddAlert) {
                TextField("Name", text: $newPlanName)
                Button("Abbrechen", role: .cancel) { }
                Button("Erstellen") {
                    createPlan()
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .alert("Plan umbenennen", isPresented: $showingRenameAlert) {
                TextField("Name", text: $newPlanName)
                Button("Abbrechen", role: .cancel) { }
                Button("Speichern") {
                    if let plan = planToRename {
                        plan.name = newPlanName
                    }
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
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
