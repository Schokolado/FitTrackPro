import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(WorkoutManager.self) private var workoutManager
    
    let viewModel: WorkoutSessionViewModel
    @Bindable var session: WorkoutSession
    
    @State private var showingCancelAlert = false
    @State private var showingConfirmFinishAlert = false
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
    
    @State private var showingAutoFinishAlert = false
    @State private var hasShownAutoFinishAlert = false
    
    @State private var expandedGroupIds: Set<String> = []
    @State private var scrollTarget: String? = nil
    
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
    
    private func isGroupCompleted(_ group: SessionExerciseGroupData) -> Bool {
        group.exerciseGroups.allSatisfy { g in
            !g.sets.isEmpty && g.sets.allSatisfy { $0.isCompleted }
        }
    }
    
    private var allSetsCompleted: Bool {
        guard let sets = session.sets, !sets.isEmpty else { return false }
        return sets.allSatisfy { $0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
                workoutSetsList
                    .background(Color.backgroundPrimary)
                    .safeAreaInset(edge: .top) {
                        WorkoutTimerHeaderView(viewModel: viewModel, planName: session.plan?.name) {
                            showingCustomTimerAlert = true
                        } onSkipRestTimer: {
                            if requireRestTimerConfirm {
                                showingSkipRestAlert = true
                            } else {
                                viewModel.skipRestTimer()
                            }
                        } onMinimize: {
                            dismiss()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                                .onEnded { value in
                                    if value.translation.height > 40 {
                                        dismiss()
                                    }
                                }
                        )
                        .background(
                            VStack(spacing: 0) {
                                Color.backgroundPrimary
                                LinearGradient(
                                    colors: [Color.backgroundPrimary, Color.backgroundPrimary.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 32)
                            }
                            .ignoresSafeArea(.container, edges: .top)
                        )
                    }
            .navigationBarHidden(true)
            .alert("Workout abbrechen?", isPresented: $showingCancelAlert) {
                Button("Ja, abbrechen", role: .destructive) {
                    modelContext.delete(session)
                    workoutManager.endWorkout()
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
            .alert("Glückwunsch!", isPresented: $showingAutoFinishAlert) {
                Button("Workout beenden") {
                    viewModel.pauseWorkout()
                    showingFinishSheet = true
                }
                Button("Cooldown fortsetzen", role: .cancel) { }
            } message: {
                Text("Du hast alle Übungen erfolgreich abgeschlossen. Möchtest du das Workout jetzt beenden oder weiterlaufen lassen (z.B. für Cooldown)?")
            }
            .onChange(of: allSetsCompleted) { oldValue, newValue in
                if newValue {
                    if !hasShownAutoFinishAlert {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingAutoFinishAlert = true
                        }
                        hasShownAutoFinishAlert = true
                    }
                } else {
                    hasShownAutoFinishAlert = false
                }
            }
            .onAppear {
                NotificationService.shared.requestAuthorization()
                
                if let firstUncompleted = sessionExerciseGroups.first(where: { !isGroupCompleted($0) }) {
                    expandedGroupIds.insert(firstUncompleted.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollTarget = firstUncompleted.id
                    }
                }
            }
            // Milestone 5: Workout Summary
            .sheet(isPresented: $showingFinishSheet) {
                WorkoutSummaryView(session: session)
                    .interactiveDismissDisabled() // User must click "Speichern"
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutFinished)) { _ in
                // End workout in manager and dismiss the view
                let finishedId = session.id.uuidString
                workoutManager.endWorkout()
                UserDefaults.standard.set(1, forKey: "mainSelectedTab")
                UserDefaults.standard.set(2, forKey: "trainingSelectedTab")
                UserDefaults.standard.set(finishedId, forKey: "openHistorySessionId")
                dismiss()
            }
            .alert("Training beenden?", isPresented: $showingConfirmFinishAlert) {
                Button("Ja, beenden") {
                    viewModel.pauseWorkout()
                    showingFinishSheet = true
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Bist du sicher, dass du das Training beenden möchtest?")
            }
        }
    }
    
    private var sessionExerciseGroups: [SessionExerciseGroupData] {
        let sortedGroups = groupedSets
        var groups: [SessionExerciseGroupData] = []
        var processedIds: Set<UUID> = []
        
        for g in sortedGroups {
            if processedIds.contains(g.id) { continue }
            
            if let groupId = g.planExercise?.supersetGroup {
                let related = sortedGroups.filter { $0.planExercise?.supersetGroup == groupId }
                for rel in related {
                    processedIds.insert(rel.id)
                }
                groups.append(SessionExerciseGroupData(id: "superset-\(groupId)", exerciseGroups: related, supersetGroupId: groupId))
            } else {
                processedIds.insert(g.id)
                groups.append(SessionExerciseGroupData(id: "single-\(g.id.uuidString)", exerciseGroups: [g], supersetGroupId: nil))
            }
        }
        
        return groups
    }

    private var workoutSetsList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: Spacing.md) {
                    ForEach(sessionExerciseGroups) { group in
                    WorkoutSupersetGroupCard(
                        sessionGroup: group,
                        session: session,
                        viewModel: viewModel,
                        isExpanded: Binding(
                            get: { expandedGroupIds.contains(group.id) },
                            set: { val in
                                if val { expandedGroupIds.insert(group.id) }
                                else { expandedGroupIds.remove(group.id) }
                            }
                        ),
                        onGroupCompleted: {
                            if let next = sessionExerciseGroups.first(where: { !isGroupCompleted($0) }) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    _ = expandedGroupIds.insert(next.id)
                                    _ = expandedGroupIds.remove(group.id)
                                }
                                scrollTarget = next.id
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    _ = expandedGroupIds.remove(group.id)
                                }
                            }
                        }
                    )
                    .padding(.bottom, Spacing.sm)
                    .id(group.id)
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
                    showingConfirmFinishAlert = true
                }) {
                    Text("Workout beenden")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .padding(.top, 12)
            .padding(.vertical)
            .onChange(of: scrollTarget) { _, newTarget in
                if let target = newTarget {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
            }
        }
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
    let id: String
    var exerciseGroups: [ExerciseGroupData]
    var supersetGroupId: Int?
}

struct WorkoutSupersetGroupCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    let sessionGroup: SessionExerciseGroupData
    let session: WorkoutSession
    let viewModel: WorkoutSessionViewModel
    @Binding var isExpanded: Bool
    var onGroupCompleted: () -> Void
    
    private var isCompleted: Bool {
        sessionGroup.exerciseGroups.allSatisfy { g in
            !g.sets.isEmpty && g.sets.allSatisfy { $0.isCompleted }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sessionGroup.supersetGroupId != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
                }) {
                    HStack {
                        HStack {
                            Image(systemName: "link")
                            Text("Supersatz")
                        }
                        .font(.caption)
                        .foregroundColor(.brandSecondary)
                        
                        Spacer()
                        
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if isExpanded {
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
                                .padding(.vertical, 8)
                        }
                    }
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
                    }) {
                        HStack(spacing: 12) {
                            SupersetIconStack(
                                exercises: sessionGroup.exerciseGroups.map { $0.exercise }
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(sessionGroup.exerciseGroups, id: \.id) { g in
                                    Text(g.exercise.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
                        groupIsCollapsed: Binding(
                            get: { !isExpanded },
                            set: { isExpanded = !$0 }
                        )
                    )
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .onChange(of: isCompleted) { oldValue, newValue in
            if newValue == true {
                onGroupCompleted()
            }
        }
    }
}

struct WorkoutExerciseInnerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
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
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { groupIsCollapsed.toggle() }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 36, height: 36)
                                
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [themeManager.color(for: exercise.category).opacity(0.7), themeManager.color(for: exercise.category)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                
                                ExerciseIconView(exercise: exercise, size: 18)
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 1, y: 0)
                            
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Menu {
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        Label("Übungsdetails ansehen", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
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
        guard session.sets != nil else { return }
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
