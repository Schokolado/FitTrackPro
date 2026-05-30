import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = WorkoutSessionViewModel()
    @Bindable var session: WorkoutSession
    
    @State private var showingCancelAlert = false
    @State private var showingFinishSheet = false
    @State private var showingSkipRestAlert = false
    @AppStorage("requireRestTimerConfirm") private var requireRestTimerConfirm = true
    
    @State private var showingExerciseSelection = false
    @State private var pendingExerciseToAdd: Exercise?
    @State private var showingAddToPlanAlert = false
    
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    @State private var showingCustomTimerAlert = false
    @State private var customTimerSeconds: String = ""
    
    private struct GroupKey: Hashable {
        let planExerciseId: UUID?
        let exerciseId: UUID
    }
    
    // Group sets by Exercise and PlanExercise for UI
    private var groupedSets: [(id: UUID, exercise: Exercise, planExercise: PlanExercise?, sets: [WorkoutSet])] {
        guard let sets = session.sets else { return [] }
        var dict: [GroupKey: [WorkoutSet]] = [:]
        
        for set in sets {
            guard let exercise = set.exercise else { continue }
            let key = GroupKey(planExerciseId: set.planExercise?.id, exerciseId: exercise.id)
            if dict[key] == nil {
                dict[key] = []
            }
            dict[key]?.append(set)
        }
        
        var result: [(id: UUID, exercise: Exercise, planExercise: PlanExercise?, sets: [WorkoutSet])] = []
        
        if let plan = session.plan, let planExercises = plan.planExercises {
            let orderedExercises = planExercises.sorted(by: { $0.sortOrder < $1.sortOrder })
            for planEx in orderedExercises {
                guard let exercise = planEx.exercise else { continue }
                let key = GroupKey(planExerciseId: planEx.id, exerciseId: exercise.id)
                if let groupSets = dict[key] {
                    result.append((id: planEx.id, exercise: exercise, planExercise: planEx, sets: groupSets.sorted(by: { $0.setNumber < $1.setNumber })))
                    dict.removeValue(forKey: key)
                }
            }
        }
        
        // Add remaining ad-hoc exercises
        let remainingKeys = dict.keys.sorted { k1, k2 in
            let t1 = dict[k1]?.first?.timestamp ?? Date.distantFuture
            let t2 = dict[k2]?.first?.timestamp ?? Date.distantFuture
            return t1 < t2
        }
        
        for key in remainingKeys {
            if let groupSets = dict[key], let firstSet = groupSets.first, let exercise = firstSet.exercise {
                let id = key.planExerciseId ?? exercise.id
                result.append((id: id, exercise: exercise, planExercise: firstSet.planExercise, sets: groupSets.sorted(by: { $0.setNumber < $1.setNumber })))
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                workoutSetsList
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.restTimerActive {
                        Button(action: {
                            if requireRestTimerConfirm {
                                showingSkipRestAlert = true
                            } else {
                                viewModel.skipRestTimer()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                Text(viewModel.formatTime(viewModel.restTimeRemaining))
                            }
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundColor(.green)
                        }
                    } else {
                        Menu {
                            Button("\(timerFav1) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav1)) }
                            Button("\(timerFav2) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav2)) }
                            Button("\(timerFav3) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav3)) }
                            Divider()
                            Button("Individuell...") {
                                showingCustomTimerAlert = true
                            }
                        } label: {
                            Image(systemName: "timer")
                                .font(.headline)
                                .foregroundColor(.brand)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(session.plan?.name ?? "Freies Workout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.formatTime(viewModel.elapsedTime))
                            .font(.headline.monospacedDigit())
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Beenden") {
                        viewModel.pauseWorkout()
                        showingFinishSheet = true
                    }
                    .bold()
                    .foregroundColor(.brand)
                }
            }
            .alert("Workout abbrechen?", isPresented: $showingCancelAlert) {
                Button("Ja, abbrechen", role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                }
                Button("Zurück", role: .cancel) {}
            } message: {
                Text("Dein bisheriger Fortschritt in diesem Workout geht verloren.")
            }
            .alert("Pause beenden?", isPresented: $showingSkipRestAlert) {
                Button("Überspringen") {
                    viewModel.skipRestTimer()
                }
                Button("Nicht mehr fragen") {
                    requireRestTimerConfirm = false
                    viewModel.skipRestTimer()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Möchtest du die Pause wirklich überspringen?")
            }
            .sheet(isPresented: $showingExerciseSelection) {
                NavigationStack {
                    ExerciseSelectionView(plan: nil) { exercise in
                        handleAdhocExercise(exercise)
                    }
                }
            }
            .alert("Zum Plan hinzufügen?", isPresented: $showingAddToPlanAlert) {
                Button("Ja, im Plan speichern") {
                    if let ex = pendingExerciseToAdd, let plan = session.plan {
                        let currentCount = plan.planExercises?.count ?? 0
                        let newPlanEx = PlanExercise(sortOrder: currentCount, targetSets: 3, targetReps: 10, restDuration: ex.defaultRestDuration, plan: plan, exercise: ex)
                        modelContext.insert(newPlanEx)
                    }
                }
                Button("Nein, nur heute", role: .cancel) {}
            } message: {
                Text("Möchtest du diese Übung dauerhaft zu '\(session.plan?.name ?? "deinem Plan")' hinzufügen?")
            }
            .alert("Eigener Timer", isPresented: $showingCustomTimerAlert) {
                TextField("Sekunden", text: $customTimerSeconds)
                    .keyboardType(.numberPad)
                Button("Starten") {
                    if let seconds = Int(customTimerSeconds), seconds > 0 {
                        viewModel.startRestTimer(duration: TimeInterval(seconds))
                    }
                    customTimerSeconds = ""
                }
                Button("Abbrechen", role: .cancel) {
                    customTimerSeconds = ""
                }
            } message: {
                Text("Gib die gewünschte Pausenzeit in Sekunden ein.")
            }
            .onAppear {
                NotificationService.shared.requestAuthorization()
                viewModel.startWorkout()
            }
            // Milestone 5: Workout Summary
            .sheet(isPresented: $showingFinishSheet) {
                WorkoutSummaryView(session: session)
                    .interactiveDismissDisabled() // User must click "Speichern"
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutFinished"))) { _ in
                // Dismiss the full screen cover when the summary is saved
                dismiss()
            }
        }
    }
    
    private var workoutSetsList: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ForEach(groupedSets, id: \.id) { group in
                    exerciseSection(for: group.exercise, planExercise: group.planExercise, sets: group.sets)
                }
                
                Button(action: {
                    showingExerciseSelection = true
                }) {
                    Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.brand)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.brandSecondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Button(action: {
                    showingCancelAlert = true
                }) {
                    Text("Workout abbrechen")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 16)
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
    }
    
    @ViewBuilder
    private func exerciseSection(for exercise: Exercise, planExercise: PlanExercise?, sets: [WorkoutSet]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ExerciseSectionHeader(exercise: exercise, currentSessionId: session.id)
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, 8)
            
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, workoutSet in
                WorkoutSetRowView(workoutSet: workoutSet) {
                    let duration = workoutSet.planExercise?.restDuration ?? exercise.defaultRestDuration
                    viewModel.startRestTimer(duration: duration)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteSet(workoutSet, from: sets)
                    } label: {
                        Label("Satz löschen", systemImage: "trash")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if index < sets.count - 1 {
                    Divider()
                        .padding(.leading)
                }
            }
            
            Button(action: {
                addSet(for: exercise, planExercise: planExercise)
            }) {
                Label("Satz hinzufügen", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundColor(.brand)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 12)
        }
        .cardStyle()
        .padding(.horizontal)
    }
    
    private func addSet(for exercise: Exercise, planExercise: PlanExercise?) {
        guard let sets = session.sets else { return }
        
        let existingSets: [WorkoutSet]
        if let planEx = planExercise {
            existingSets = sets.filter { $0.planExercise?.id == planEx.id }
        } else {
            existingSets = sets.filter { $0.exercise?.id == exercise.id && $0.planExercise == nil }
        }
        
        let newSetNumber = (existingSets.max(by: { $0.setNumber < $1.setNumber })?.setNumber ?? 0) + 1
        
        let newSet = WorkoutSet(
            setNumber: newSetNumber,
            session: session,
            exercise: exercise,
            planExercise: planExercise
        )
        modelContext.insert(newSet)
    }
    
    private func deleteSet(_ setToDelete: WorkoutSet, from sets: [WorkoutSet]) {
        modelContext.delete(setToDelete)
        
        let remainingSets = sets.filter { $0.id != setToDelete.id }.sorted(by: { $0.setNumber < $1.setNumber })
        for (index, set) in remainingSets.enumerated() {
            set.setNumber = index + 1
        }
    }
    
    private func handleAdhocExercise(_ exercise: Exercise) {
        // Add one empty set so it appears in the active session
        let newSet = WorkoutSet(setNumber: 1, session: session, exercise: exercise)
        modelContext.insert(newSet)
        
        // Ask if it should be saved to the underlying plan
        if session.plan != nil {
            self.pendingExerciseToAdd = exercise
            // Delay alert to avoid sheet presentation conflict
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingAddToPlanAlert = true
            }
        }
    }
}

struct ExerciseSectionHeader: View {
    let exercise: Exercise
    let currentSessionId: UUID
    
    @Query private var pastSets: [WorkoutSet]
    @State private var showingHistory = false
    
    init(exercise: Exercise, currentSessionId: UUID) {
        self.exercise = exercise
        self.currentSessionId = currentSessionId
        let exerciseId = exercise.id
        
        _pastSets = Query(
            filter: #Predicate<WorkoutSet> { set in
                set.exercise?.id == exerciseId && set.isCompleted == true && set.session?.id != currentSessionId
            },
            sort: \.timestamp, order: .reverse
        )
    }
    
    var body: some View {
        HStack {
            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
                
            Spacer()
            
            Button(action: { showingHistory = true }) {
                if let lastSet = pastSets.first {
                    Text("Zuletzt: \(lastSet.actualWeight, specifier: "%.1f") kg × \(lastSet.actualReps)")
                        .font(.caption)
                        .foregroundColor(.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.brand)
                }
            }
            .textCase(nil)
        }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
        }
    }
}
