import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: TrainingPlan
    
    @State private var showingExerciseSelection = false
    @State private var showingEditNameAlert = false
    @State private var editName = ""
    @State private var activeSession: WorkoutSession? = nil
    @State private var showingReorderSheet = false
    
    private var groupedExercises: [ExerciseGroup] {
        let sorted = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        var groups: [ExerciseGroup] = []
        var currentGroup: ExerciseGroup?
        
        for ex in sorted {
            if let groupId = ex.supersetGroup {
                if currentGroup?.supersetGroupId == groupId {
                    currentGroup?.exercises.append(ex)
                } else {
                    if let cg = currentGroup { groups.append(cg) }
                    currentGroup = ExerciseGroup(exercises: [ex], supersetGroupId: groupId)
                }
            } else {
                if let cg = currentGroup { groups.append(cg) }
                currentGroup = nil
                groups.append(ExerciseGroup(exercises: [ex], supersetGroupId: nil))
            }
        }
        if let cg = currentGroup { groups.append(cg) }
        return groups
    }
    
    var body: some View {
        List {
            Section {
                Button(action: { startWorkout() }) {
                    Label("Workout Starten", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.brand)
            }
            
            ForEach(groupedExercises) { group in
                Section {
                    ForEach(group.exercises) { planEx in
                        PlanExerciseRowView(planExercise: planEx)
                    }
                    .onDelete(perform: { offsets in
                        deleteExercises(offsets: offsets, from: group)
                    })
                } header: {
                    if group.supersetGroupId != nil {
                        HStack {
                            Image(systemName: "link")
                            Text("Supersatz")
                        }
                        .font(.caption)
                        .foregroundColor(.brandSecondary)
                        .padding(.bottom, 2)
                    }
                }
            }
            
            Section {
                Button(action: { showingExerciseSelection = true }) {
                    Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.brand)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        editName = plan.name
                        showingEditNameAlert = true
                    }) {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    Button(action: {
                        showingReorderSheet = true
                    }) {
                        Label("Sortieren", systemImage: "arrow.up.arrow.down")
                    }
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Plan umbenennen", isPresented: $showingEditNameAlert) {
            TextField("Name", text: $editName)
            Button("Abbrechen", role: .cancel) { }
            Button("Speichern") {
                plan.name = editName
            }
            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .sheet(isPresented: $showingExerciseSelection) {
            NavigationStack {
                ExerciseSelectionView(plan: plan)
            }
        }
        .sheet(isPresented: $showingReorderSheet) {
            PlanExerciseReorderView(plan: plan)
        }
        .fullScreenCover(item: $activeSession) { session in
            WorkoutSessionView(session: session)
        }
    }
    
    private func startWorkout() {
        // Create a new session for this plan
        let newSession = WorkoutSession(plan: plan)
        modelContext.insert(newSession)
        
        // Prefill sets based on PlanExercises
        let sortedExercises = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        for planEx in sortedExercises {
            for setIndex in 0..<planEx.targetSets {
                let workoutSet = WorkoutSet(
                    setNumber: setIndex + 1,
                    actualWeight: planEx.targetWeight ?? 0.0,
                    actualReps: planEx.targetReps,
                    session: newSession,
                    exercise: planEx.exercise,
                    planExercise: planEx
                )
                modelContext.insert(workoutSet)
            }
        }
        
        activeSession = newSession
    }
    
    private func deleteExercises(offsets: IndexSet, from group: ExerciseGroup) {
        for index in offsets {
            let item = group.exercises[index]
            modelContext.delete(item)
        }
    }
}

struct ExerciseGroup: Identifiable {
    let id = UUID()
    var exercises: [PlanExercise]
    var supersetGroupId: Int?
}

struct PlanExerciseReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: TrainingPlan
    
    var body: some View {
        NavigationStack {
            List {
                let sortedExercises = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
                ForEach(sortedExercises) { planEx in
                    HStack {
                        Text(planEx.exercise?.name ?? "Gelöschte Übung")
                        Spacer()
                        if planEx.supersetGroup != nil {
                            Image(systemName: "link")
                                .foregroundColor(.brandSecondary)
                        }
                    }
                }
                .onMove(perform: moveExercises)
            }
            .navigationTitle("Reihenfolge ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var revisedItems = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
    }
}
