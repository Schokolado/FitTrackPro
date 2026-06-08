import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutManager.self) private var workoutManager
    @Query(sort: \PlanGroup.sortOrder) private var groups: [PlanGroup]
    @Bindable var plan: TrainingPlan
    
    @State private var showingExerciseSelection = false
    @State private var showingEditNameAlert = false
    @State private var showingEditNotesAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingActiveWorkoutAlert = false
    @State private var editName = ""
    @State private var editNotes = ""
    @State private var showingReorderSheet = false
    @State private var refreshId = UUID()
    @State private var newlyAddedExerciseIds: Set<UUID> = []
    @State private var expandedGroups: Set<String> = []
    @State private var expandedExercises: Set<UUID> = []
    
    @State private var showingCreateGroupAlert = false
    @State private var newGroupName = ""
    
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var allSessions: [WorkoutSession]
    @State private var showingShareSheet = false
    @State private var generatedPDFUrl: URL?
    @State private var isGeneratingPDF = false
    
    private var planSessions: [WorkoutSession] {
        allSessions.filter { $0.plan?.id == plan.id }
    }
    
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
    
    private var mainContent: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: Spacing.md) {
                    
                    Text(plan.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        
                    if !plan.notes.isEmpty {
                        Text(plan.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    
                    if !groupedExercises.isEmpty {
                        startWorkoutButton
                    }
                    
                    ForEach(groupedExercises) { group in
                        exerciseGroupView(for: group)
                    }
                    
                    addExerciseButton
                }
                .padding(.vertical)
                .onChange(of: newlyAddedExerciseIds) { oldValue, newValue in
                    if let newId = newValue.subtracting(oldValue).first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring()) {
                                proxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var startWorkoutButton: some View {
        Button(action: { 
            if workoutManager.isWorkoutActive {
                showingActiveWorkoutAlert = true
            } else {
                executeStartWorkout()
            }
        }) {
            Label("Workout Starten", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .primaryButtonStyle()
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
    

    
    var body: some View {
        mainContent
        .id(refreshId)
        .background(Color.backgroundPrimary)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isGeneratingPDF {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Menu {
                            Button {
                                exportEmptyPlan()
                            } label: {
                                Label("Leerer Plan", systemImage: "doc.text")
                            }
                            
                            Button {
                                exportHistoricalPlan()
                            } label: {
                                Label("Historischer Verlauf", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    
                    Menu {
                    Button {
                        editName = plan.name
                        showingEditNameAlert = true
                    } label: {
                        Label("Plan umbenennen", systemImage: "character.cursor.ibeam")
                    }
                    
                    Button {
                        editNotes = plan.notes
                        showingEditNotesAlert = true
                    } label: {
                        Label("Notizen bearbeiten", systemImage: "note.text")
                    }
                    
                    Button {
                        showingReorderSheet = true
                    } label: {
                        Label("Reihenfolge ändern", systemImage: "arrow.up.arrow.down")
                    }
                    
                    Divider()
                    
                    Menu {
                        Button {
                            plan.group = nil
                        } label: {
                            HStack {
                                Text("Nicht zugeordnet")
                                if plan.group == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(groups) { group in
                            Button {
                                plan.group = group
                            } label: {
                                HStack {
                                    Text(group.name)
                                    if plan.group?.id == group.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            newGroupName = ""
                            showingCreateGroupAlert = true
                        } label: {
                            Label("Neue Gruppe erstellen", systemImage: "plus")
                        }
                    } label: {
                        Label("Gruppe zuweisen", systemImage: "folder")
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
        }
        .alert("Plan umbenennen", isPresented: $showingEditNameAlert) {
            TextField("Name", text: $editName)
            Button("Abbrechen", role: .cancel) { }
            Button("Speichern") {
                plan.name = editName
            }
            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .sheet(isPresented: $showingEditNotesAlert) {
            NavigationStack {
                Form {
                    Section(header: Text("Notizen")) {
                        TextField("Notizen eingeben...", text: $editNotes, axis: .vertical)
                            .lineLimit(5...20)
                    }
                }
                .navigationTitle("Notizen bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showingEditNotesAlert = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            plan.notes = editNotes
                            showingEditNotesAlert = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
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
        .alert("Neue Gruppe", isPresented: $showingCreateGroupAlert) {
            TextField("Gruppenname", text: $newGroupName)
            Button("Abbrechen", role: .cancel) { }
            Button("Erstellen") {
                let newGroup = PlanGroup(name: newGroupName, sortOrder: groups.count)
                modelContext.insert(newGroup)
                plan.group = newGroup
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .alert("Aktives Workout beenden?", isPresented: $showingActiveWorkoutAlert) {
            Button("Beenden & Neu starten", role: .destructive) {
                workoutManager.endWorkout()
                executeStartWorkout()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Du hast bereits ein laufendes Workout. Möchtest du dieses beenden und das neue Workout starten?")
        }
        .sheet(isPresented: $showingExerciseSelection) {
            NavigationStack {
                ExerciseSelectionView(plan: plan, onExerciseAdded: { newPlanEx in
                    newlyAddedExerciseIds.insert(newPlanEx.id)
                })
            }
        }
        .sheet(isPresented: $showingReorderSheet) {
            PlanExerciseReorderView(plan: plan)
        }
        .onAppear {
            cleanupPlanExercises()
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            if let url = generatedPDFUrl {
                try? FileManager.default.removeItem(at: url)
            }
        }) {
            if let url = generatedPDFUrl {
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func exportEmptyPlan() {
        isGeneratingPDF = true
        // Yield to main thread to show progress view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportEmptyPlan(plan) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }

    private func exportHistoricalPlan() {
        isGeneratingPDF = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportHistoricalPlan(plan: plan, sessions: planSessions) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }
    
    private func cleanupPlanExercises() {
        let sorted = (plan.planExercises ?? [])
            .filter { $0.exercise != nil }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
        
        var newOrder: [PlanExercise] = []
        var processedIds: Set<UUID> = []
        
        var changed = false

        for ex in sorted {
            if processedIds.contains(ex.id) { continue }
            if let groupId = ex.supersetGroup {
                let related = sorted.filter { $0.supersetGroup == groupId }
                if related.count == 1 {
                    // Orphaned superset! Remove the group id.
                    ex.supersetGroup = nil
                    changed = true
                    newOrder.append(ex)
                    processedIds.insert(ex.id)
                } else {
                    newOrder.append(contentsOf: related)
                    for r in related { processedIds.insert(r.id) }
                }
            } else {
                newOrder.append(ex)
                processedIds.insert(ex.id)
            }
        }
        
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
    
    private func executeStartWorkout() {
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
                workoutSet.session = newSession
                workoutSet.exercise = planEx.exercise
                workoutSet.planExercise = planEx
            }
        }
        
        try? modelContext.save()
        workoutManager.startWorkout(session: newSession)
        
        // Use AppRouter's binding indirectly by starting the session in WorkoutManager
        // Since WorkoutManager state updates, MainTabView will present the fullScreenCover.
    }
    
    private func deleteExercises(offsets: IndexSet, from group: ExerciseGroup) {
        for index in offsets {
            let item = group.exercises[index]
            modelContext.delete(item)
        }
    }
    
    @ViewBuilder
    private func exerciseGroupView(for group: ExerciseGroup) -> some View {
        let isExpanded = expandedGroups.contains(group.id)
        VStack(alignment: .leading, spacing: 0) {
            if group.supersetGroupId != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if isExpanded {
                            expandedGroups.remove(group.id)
                        } else {
                            expandedGroups.insert(group.id)
                        }
                    }
                }) {
                    HStack {
                        HStack {
                            Image(systemName: "link")
                            Text("Supersatz")
                        }
                        .font(.caption)
                        .foregroundColor(.brandSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if group.supersetGroupId != nil && !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        _ = expandedGroups.insert(group.id)
                    }
                }) {
                    HStack(spacing: 12) {
                        SupersetIconStack(
                            exercises: group.exercises.compactMap { $0.exercise }
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(group.exercises) { planEx in
                                Text(planEx.exercise?.name ?? "Unbekannt")
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
            } else {
                ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, planEx in
                    exerciseRow(for: planEx, in: group)
                        .id(planEx.id)
                        .padding(.horizontal)
                    
                    if index < group.exercises.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func exerciseRow(for planEx: PlanExercise, in group: ExerciseGroup) -> some View {
        PlanExerciseRowView(
            planExercise: planEx,
            onReorder: {
                showingReorderSheet = true
            },
            onSupersetChanged: {
                refreshId = UUID()
            },
            isExpanded: binding(for: group, planEx: planEx)
        )
    }
    
    private func binding(for group: ExerciseGroup, planEx: PlanExercise) -> Binding<Bool> {
        Binding(
            get: {
                if group.supersetGroupId != nil {
                    return expandedGroups.contains(group.id)
                } else {
                    return expandedExercises.contains(planEx.id) || newlyAddedExerciseIds.contains(planEx.id)
                }
            },
            set: { val in
                if group.supersetGroupId != nil {
                    if val { expandedGroups.insert(group.id) }
                    else { expandedGroups.remove(group.id) }
                } else {
                    if val { expandedExercises.insert(planEx.id) }
                    else {
                        expandedExercises.remove(planEx.id)
                        newlyAddedExerciseIds.remove(planEx.id)
                    }
                }
            }
        )
    }
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
