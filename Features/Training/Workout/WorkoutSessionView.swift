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
                // Top HUD
                VStack(spacing: 8) {
                    Text(viewModel.currentTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.plan?.name ?? "Freies Workout")
                                .font(.headline)
                            Text(viewModel.formatTime(viewModel.elapsedTime))
                                .font(.title3.monospacedDigit())
                                .foregroundColor(.brand)
                        }
                        
                        Spacer()
                        
                        Button("Beenden") {
                            viewModel.pauseWorkout()
                            showingFinishSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.success)
                    }
                }
                .padding()
                .background(Color.backgroundCard)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
                
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
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(16)
                    }
                    .padding()
                    .background(Color.brand)
                    .foregroundColor(.white)
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: viewModel.restTimerActive)
                }
                
                // Workout Sets List
                List {
                    ForEach(groupedSets, id: \.0.id) { (exercise, sets) in
                        Section(header: Text(exercise.name).font(.headline).foregroundColor(.primary)) {
                            ForEach(sets) { workoutSet in
                                WorkoutSetRowView(workoutSet: workoutSet) {
                                    // Trigger Rest Timer
                                    let duration = workoutSet.planExercise?.restDuration ?? exercise.defaultRestDuration
                                    viewModel.startRestTimer(duration: duration)
                                }
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
                    .foregroundColor(.destructive)
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
            // Transition to Milestone 5 Placeholder
            .sheet(isPresented: $showingFinishSheet) {
                // Milestone 5: WorkoutSummaryView
                VStack(spacing: 20) {
                    Text("Workout abgeschlossen! 🎉")
                        .font(.title)
                    Text("Hier kommt in Milestone 5 die Zusammenfassung inkl. Ratings.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Speichern & Schließen") {
                        session.endTime = Date()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .presentationDetents([.medium])
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
}
