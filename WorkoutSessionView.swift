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
    private var groupedSets: [ExerciseGroupData] {
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
        
        var result: [ExerciseGroupData] = []
        
        if let plan = session.plan, let planExercises = plan.planExercises {
            let orderedExercises = planExercises.sorted(by: { $0.sortOrder < $1.sortOrder })
            for planEx in orderedExercises {
                guard let exercise = planEx.exercise else { continue }
                let key = GroupKey(planExerciseId: planEx.id, exerciseId: exercise.id)
                if let groupSets = dict[key] {
                    result.append(ExerciseGroupData(id: planEx.id, exercise: exercise, planExercise: planEx, sets: groupSets.sorted(by: { $0.setNumber < $1.setNumber })))
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
                result.append(ExerciseGroupData(id: id, exercise: exercise, planExercise: firstSet.planExercise, sets: groupSets.sorted(by: { $0.setNumber < $1.setNumber })))
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
    
    private var sessionExerciseGroups: [SessionExerciseGroupData] {
        let sortedGroups = groupedSets
        var groups: [SessionExerciseGroupData] = []
        var currentGroup: SessionExerciseGroupData?
        
        for g in sortedGroups {
            if let groupId = g.planExercise?.supersetGroup {
                if currentGroup?.supersetGroupId == groupId {
                    currentGroup?.exerciseGroups.append(g)
                } else {
                    if let cg = currentGroup { groups.append(cg) }
                    currentGroup = SessionExerciseGroupData(id: UUID(), exerciseGroups: [g], supersetGroupId: groupId)
                }
            } else {
                if let cg = currentGroup { groups.append(cg) }
                currentGroup = nil
                groups.append(SessionExerciseGroupData(id: UUID(), exerciseGroups: [g], supersetGroupId: nil))
            }
        }
        if let cg = currentGroup { groups.append(cg) }
        return groups
    }

    private var workoutSetsList: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ForEach(sessionExerciseGroups, id: \.id) { sessionGroup in
                    WorkoutSupersetGroupCard(
                        sessionGroup: sessionGroup,
                        session: session,
                        viewModel: viewModel
                    )
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

struct ExerciseGroupData: Identifiable {
    let id: UUID
    let exercise: Exercise
    let planExercise: PlanExercise?
    var sets: [WorkoutSet]
}

struct SessionExerciseGroupData: Identifiable {
    let id: UUID
    var exerciseGroups: [ExerciseGroupData]
    var supersetGroupId: Int?
}

struct WorkoutSupersetGroupCard: View {
    @Environment(\.modelContext) private var modelContext
    let sessionGroup: SessionExerciseGroupData
    let session: WorkoutSession
    let viewModel: WorkoutSessionViewModel
    
    @State private var isCollapsed: Bool = false
    
    private var isCompleted: Bool {
        sessionGroup.exerciseGroups.allSatisfy { g in
            !g.sets.isEmpty && g.sets.allSatisfy { $0.isCompleted }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sessionGroup.supersetGroupId != nil {
                HStack {
                    HStack {
                        Image(systemName: "link")
                        Text("Supersatz")
                    }
                    .font(.caption)
                    .foregroundColor(.brandSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Button(action: {
                            withAnimation { isCollapsed.toggle() }
                        }) {
                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, isCollapsed ? Spacing.sm : 8)
                
                if !isCollapsed {
                    ForEach(Array(sessionGroup.exerciseGroups.enumerated()), id: \.element.id) { index, group in
                        WorkoutExerciseInnerView(
                            exercise: group.exercise,
                            planExercise: group.planExercise,
                            sets: group.sets,
                            session: session,
                            viewModel: viewModel,
                            isSuperset: true,
                            groupIsCollapsed: .constant(false)
                        )
                        
                        if index < sessionGroup.exerciseGroups.count - 1 {
                            Divider()
                                .padding(.leading)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sessionGroup.exerciseGroups) { g in
                            Text(g.exercise.name)
                                .font(.headline)
                                .foregroundColor(.brand)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Spacing.md)
                }
            } else {
                if let group = sessionGroup.exerciseGroups.first {
                    WorkoutExerciseInnerView(
                        exercise: group.exercise,
                        planExercise: group.planExercise,
                        sets: group.sets,
                        session: session,
                        viewModel: viewModel,
                        isSuperset: false,
                        groupIsCollapsed: $isCollapsed
                    )
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .onChange(of: isCompleted) { oldValue, newValue in
            if newValue == true {
                withAnimation { isCollapsed = true }
            }
        }
    }
}

struct WorkoutExerciseInnerView: View {
    @Environment(\.modelContext) private var modelContext
    let exercise: Exercise
    let planExercise: PlanExercise?
    let sets: [WorkoutSet]
    let session: WorkoutSession
    let viewModel: WorkoutSessionViewModel
    let isSuperset: Bool
    @Binding var groupIsCollapsed: Bool
    
    private var isCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                    HStack {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundColor(.brand)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                
                if !isSuperset {
                    HStack(spacing: 8) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Button(action: {
                            withAnimation { groupIsCollapsed.toggle() }
                        }) {
                            Image(systemName: groupIsCollapsed ? "chevron.down" : "chevron.up")
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, isSuperset ? 8 : Spacing.sm)
            .padding(.bottom, (isSuperset ? false : groupIsCollapsed) ? Spacing.sm : 8)
            
            if !(isSuperset ? false : groupIsCollapsed) {
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
        }
    }
    
    private func addSet(for exercise: Exercise, planExercise: PlanExercise?) {
        guard let sessionSets = session.sets else { return }
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
}

struct ExerciseSectionHeader: View {
    let exercise: Exercise
    let currentSessionId: UUID
    
    init(exercise: Exercise, currentSessionId: UUID) {
        self.exercise = exercise
        self.currentSessionId = currentSessionId
    }
    
    var body: some View {
        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(.brand)
                    
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
