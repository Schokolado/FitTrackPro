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
        var dict: [UUID: [WorkoutSet]] = [:]
        var exercises: [Exercise] = []
        
        for set in sets.sorted(by: { $0.setNumber < $1.setNumber }) {
            guard let exercise = set.exercise else { continue }
            if dict[exercise.id] == nil {
                dict[exercise.id] = []
                exercises.append(exercise)
            }
            dict[exercise.id]?.append(set)
        }
        
        return exercises.map { ($0, dict[$0.id]!) }
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brand.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .foregroundColor(.brand)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
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
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        showingCancelAlert = true
                    }
                    .foregroundColor(.red)
                }
                
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
