import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = WorkoutSessionViewModel()
    @Bindable var session: WorkoutSession
    
    @State private var showingCancelAlert = false
    @State private var showingFinishSheet = false
    
    // Group sets by Exercise for UI
    private var groupedSets: [(Exercise, [WorkoutSet])] {
        guard let sets = session.sets else { return [] }
        var dict: [Exercise: [WorkoutSet]] = [:]
        
        for set in sets {
            guard let exercise = set.exercise else { continue }
            if dict[exercise] == nil {
                dict[exercise] = []
            }
            dict[exercise]?.append(set)
        }
        
        var sortedExercises: [Exercise] = []
        if let plan = session.plan, let planExercises = plan.planExercises {
            let orderedExercises = planExercises.sorted(by: { $0.sortOrder < $1.sortOrder }).compactMap { $0.exercise }
            sortedExercises = orderedExercises.filter { dict.keys.contains($0) }
            let remaining = dict.keys.filter { !orderedExercises.contains($0) }.sorted(by: { $0.name < $1.name })
            sortedExercises.append(contentsOf: remaining)
        } else {
            // Sort by earliest timestamp of their sets as fallback
            sortedExercises = dict.keys.sorted { e1, e2 in
                let t1 = dict[e1]?.first?.timestamp ?? Date.distantFuture
                let t2 = dict[e2]?.first?.timestamp ?? Date.distantFuture
                return t1 < t2
            }
        }
        
        return sortedExercises.map { ($0, dict[$0]!.sorted(by: { $0.setNumber < $1.setNumber })) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Rest Timer Banner
                if viewModel.restTimerActive {
                    HStack {
                        Image(systemName: "timer")
                        Text("Pause: \(viewModel.formatTime(viewModel.restTimeRemaining))")
                            .font(.headline.monospacedDigit())
                        
                        Spacer()
                        
                        Button("Überspringen") {
                            viewModel.skipRestTimer()
                        }
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(16)
                    }
                    .padding()
                    .background(Color.green.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.3), radius: 5, y: 3)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.restTimerActive)
                }
                
                // Workout Sets List
                List {
                    ForEach(groupedSets, id: \.0.id) { (exercise, sets) in
                        Section(header: ExerciseSectionHeader(exercise: exercise, currentSessionId: session.id)) {
                            ForEach(sets) { workoutSet in
                                WorkoutSetRowView(workoutSet: workoutSet) {
                                    // Trigger Rest Timer
                                    let duration = workoutSet.planExercise?.restDuration ?? exercise.defaultRestDuration
                                    viewModel.startRestTimer(duration: duration)
                                }
                            }
                            .onDelete { offsets in
                                deleteSets(at: offsets, from: sets)
                            }
                            
                            Button(action: {
                                addSet(for: exercise)
                            }) {
                                Label("Satz hinzufügen", systemImage: "plus")
                                    .font(.subheadline)
                                    .foregroundColor(.brand)
                            }
                        }
                    }
                    
                    Section {
                        Button(action: {
                            showingCancelAlert = true
                        }) {
                            Text("Workout abbrechen")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
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
                Button("Nein", role: .cancel) { }
                Button("Ja, verwerfen", role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                }
            } message: {
                Text("Dein bisheriger Fortschritt in diesem Workout geht verloren.")
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
    
    private func addSet(for exercise: Exercise) {
        guard let sets = session.sets else { return }
        let existingSets = sets.filter { $0.exercise?.id == exercise.id }
        let newSetNumber = (existingSets.max(by: { $0.setNumber < $1.setNumber })?.setNumber ?? 0) + 1
        
        let newSet = WorkoutSet(
            setNumber: newSetNumber,
            session: session,
            exercise: exercise
        )
        modelContext.insert(newSet)
    }
    
    private func deleteSets(at offsets: IndexSet, from sets: [WorkoutSet]) {
        for index in offsets {
            let setToDelete = sets[index]
            modelContext.delete(setToDelete)
        }
        
        // Renumber remaining sets for this exercise
        let remainingSets = sets.enumerated().filter { !offsets.contains($0.offset) }.map { $0.element }
        for (index, set) in remainingSets.sorted(by: { $0.setNumber < $1.setNumber }).enumerated() {
            set.setNumber = index + 1
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
            Text(exercise.name)
                .font(.headline)
                .foregroundColor(.primary)
                
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
