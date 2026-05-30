import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: TrainingPlan
    
    @State private var showingExerciseSelection = false
    @State private var showingEditNameAlert = false
    @State private var showingDeleteAlert = false
    @State private var editName = ""
    @State private var activeSession: WorkoutSession? = nil
    @State private var showingReorderSheet = false
    @State private var refreshId = UUID()
    
    private var groupedExercises: [ExerciseGroup] {
        plan.groupedPlanExercises
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if !groupedExercises.isEmpty {
                    Button(action: { startWorkout() }) {
                        Label("Workout Starten", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                    .padding(.horizontal)
                }
                
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
                            .padding(.top, Spacing.md)
                            .padding(.bottom, 8)
                        }
                        
                        ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, planEx in
                            PlanExerciseRowView(planExercise: planEx, onReorder: {
                                showingReorderSheet = true
                            }, onSupersetChanged: {
                                refreshId = UUID()
                            })
                                .padding(.horizontal)
                            
                            if index < group.exercises.count - 1 {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .cardStyle()
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
        .id(refreshId)
        .background(Color.backgroundPrimary)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        editName = plan.name
                        showingEditNameAlert = true
                    } label: {
                        Label("Plan umbenennen", systemImage: "character.cursor.ibeam")
                    }
                    
                    Button {
                        showingReorderSheet = true
                    } label: {
                        Label("Reihenfolge ändern", systemImage: "arrow.up.arrow.down")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Plan löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "pencil")
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
        .alert("Plan löschen", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                modelContext.delete(plan)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchtest du diesen Trainingsplan wirklich löschen?")
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
        .onAppear {
            cleanupPlanExercises()
        }
    }
    
    private func cleanupPlanExercises() {
        var sorted = (plan.planExercises ?? [])
            .filter { $0.exercise != nil }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
        
        var newOrder: [PlanExercise] = []
        var processedIds: Set<UUID> = []
        
        for ex in sorted {
            if processedIds.contains(ex.id) { continue }
            if let groupId = ex.supersetGroup {
                let related = sorted.filter { $0.supersetGroup == groupId }
                newOrder.append(contentsOf: related)
                for r in related { processedIds.insert(r.id) }
            } else {
                newOrder.append(ex)
                processedIds.insert(ex.id)
            }
        }
        
        var changed = false
        for (i, ex) in newOrder.enumerated() {
            if ex.sortOrder != i {
                ex.sortOrder = i
                changed = true
            }
        }
        
        // Remove zombies permanently from the array
        // Remove zombies permanently from the array and DB
        let zombies = plan.planExercises?.filter { $0.exercise == nil } ?? []
        for zombie in zombies {
            modelContext.delete(zombie)
            changed = true
        }
        plan.planExercises?.removeAll { $0.exercise == nil }
        
        if changed {
            try? modelContext.save()
        }
    }
    
    private func startWorkout() {
        let newSession = WorkoutSession(plan: plan)
        modelContext.insert(newSession)

        let sortedExercises = (plan.planExercises ?? [])
            .filter { $0.exercise != nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        for planEx in sortedExercises {
            for setIndex in 0..<planEx.targetSets {
                let workoutSet = WorkoutSet(
                    setNumber: setIndex + 1,
                    actualWeight: planEx.targetWeight ?? 0.0,
                    actualReps: planEx.targetReps
                )
                modelContext.insert(workoutSet)
                // Fix SwiftData relationship dropping by assigning after insertion
                workoutSet.exercise = planEx.exercise
                workoutSet.planExercise = planEx
            }
        }
        
        try? modelContext.save()
        activeSession = newSession
    }
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
