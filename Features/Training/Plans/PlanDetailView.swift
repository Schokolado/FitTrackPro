import SwiftUI
import SwiftData

// MARK: - PlanDetailView

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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if !plan.groupedPlanExercises.isEmpty {
                    Button(action: { startWorkout() }) {
                        Label("Workout Starten", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                    .padding(.horizontal)
                }

                ForEach(plan.groupedPlanExercises) { group in
                    exerciseGroupCard(group)
                }

                addExerciseButton
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .alert("Plan umbenennen", isPresented: $showingEditNameAlert) {
            TextField("Name", text: $editName)
            Button("Abbrechen", role: .cancel) { }
            Button("Speichern") { plan.name = editName }
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
            NavigationStack { ExerciseSelectionView(plan: plan) }
        }
        .sheet(isPresented: $showingReorderSheet) {
            PlanExerciseReorderView(plan: plan)
        }
        .fullScreenCover(item: $activeSession) { session in
            WorkoutSessionView(session: session)
        }
    }

    // MARK: - Subviews

    private func exerciseGroupCard(_ group: ExerciseGroup) -> some View {
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
                .padding(.bottom, Spacing.sm)
            }

            ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, planEx in
                PlanExerciseRowView(planExercise: planEx) {
                    showingReorderSheet = true
                }
                .padding(.horizontal)

                if index < group.exercises.count - 1 {
                    Divider().padding(.leading)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private var addExerciseButton: some View {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    // MARK: - Actions

    private func startWorkout() {
        let newSession = WorkoutSession(plan: plan)
        modelContext.insert(newSession)

        let sortedExercises = (plan.planExercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
        for planEx in sortedExercises {
            for setIndex in 0..<planEx.targetSets {
                let workoutSet = WorkoutSet(
                    setNumber: setIndex + 1,
                    actualWeight: planEx.targetWeight ?? 0.0,
                    actualReps: planEx.targetReps
                )
                modelContext.insert(workoutSet)
                // Fix SwiftData relationship dropping by assigning after insertion
                workoutSet.session = newSession
                workoutSet.exercise = planEx.exercise
                workoutSet.planExercise = planEx
            }
        }
        
        try? modelContext.save()
        activeSession = newSession
    }
}

// MARK: - PlanExerciseReorderView

struct PlanExerciseReorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: TrainingPlan

    var body: some View {
        NavigationStack {
            List {
                ForEach(plan.groupedPlanExercises) { group in
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
                                .padding(.leading, group.supersetGroupId != nil ? Spacing.md : 0)
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
                    Button("Fertig") { dismiss() }
                        .bold()
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }

    // MARK: - Actions

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var groups = plan.groupedPlanExercises
        groups.move(fromOffsets: source, toOffset: destination)

        let flattened = groups.flatMap { $0.exercises }
        for (index, planEx) in flattened.enumerated() {
            planEx.sortOrder = index
        }
    }

    private func deleteGroups(at offsets: IndexSet) {
        let groups = plan.groupedPlanExercises
        for index in offsets {
            let group = groups[index]
            for planEx in group.exercises {
                plan.planExercises?.removeAll { $0.id == planEx.id }
                modelContext.delete(planEx)
            }
        }

        let remaining = plan.groupedPlanExercises.flatMap { $0.exercises }
        for (index, planEx) in remaining.enumerated() {
            planEx.sortOrder = index
        }
    }
}
