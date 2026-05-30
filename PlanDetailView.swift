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
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Button(action: { startWorkout() }) {
                    Label("Workout Starten", systemImage: "play.fill")
                }
                .primaryButtonStyle()
                .padding(.horizontal)
                
                ForEach(groupedExercises) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        if group.supersetGroupId != nil {
                            HStack {
                                Image(systemName: "link")
                                Text("Supersatz")
                            }
                            .font(.caption)
                            .foregroundColor(.brandSecondary)
                            .padding(.horizontal)
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, 4)
                        }
                        
                        ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, planEx in
                            PlanExerciseRowView(planExercise: planEx)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            
                            if index < group.exercises.count - 1 {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .cardStyle()
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        showingReorderSheet = true
                    }
                    .padding(.horizontal)
                }
                
                Button(action: { showingExerciseSelection = true }) {
                    Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.brand)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.brandSecondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showingReorderSheet = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    Button(action: {
                        editName = plan.name
                        showingEditNameAlert = true
                    }) {
                        Image(systemName: "pencil")
                    }
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: TrainingPlan
    
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
        NavigationStack {
            List {
                ForEach(groupedExercises) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        if group.supersetGroupId != nil {
                            HStack {
                                Image(systemName: "link")
                                Text("Supersatz")
                            }
                            .font(.caption)
                            .foregroundColor(.brandSecondary)
                        }
                        
                        ForEach(group.exercises) { planEx in
                            Text(planEx.exercise?.name ?? "Gelöschte Übung")
                                .padding(.leading, group.supersetGroupId != nil ? 16 : 0)
                        }
                    }
                }
                .onDelete(perform: deleteGroups)
                .onMove(perform: moveGroups)
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
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var groups = groupedExercises
        groups.move(fromOffsets: source, toOffset: destination)
        
        let flattened = groups.flatMap { $0.exercises }
        for (index, planEx) in flattened.enumerated() {
            planEx.sortOrder = index
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        let groups = groupedExercises
        for index in offsets {
            let group = groups[index]
            for planEx in group.exercises {
                plan.planExercises?.removeAll(where: { $0.id == planEx.id })
                modelContext.delete(planEx)
            }
        }
        
        let remaining = groupedExercises.flatMap { $0.exercises }
        for (index, planEx) in remaining.enumerated() {
            planEx.sortOrder = index
        }
    }
}
