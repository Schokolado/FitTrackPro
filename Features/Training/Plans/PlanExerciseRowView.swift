import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Bindable var planExercise: PlanExercise
    var onReorder: (() -> Void)? = nil
    var onSupersetChanged: (() -> Void)? = nil
    @Binding var isExpanded: Bool
    @State private var showingDeleteAlert = false
    @State private var showingNotesSheet = false
    @State private var startEditingNotes = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let exercise = planExercise.exercise {
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 40, height: 40)
                                    
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [themeManager.color(for: exercise.category).opacity(0.7), themeManager.color(for: exercise.category)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                
                                ExerciseIconView(exercise: exercise, size: 20)
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 1, y: 0)
                            
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if !planExercise.planSpecificNotes.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.subheadline)
                                    .foregroundColor(.brand)
                                    .onTapGesture {
                                        startEditingNotes = false
                                        showingNotesSheet = true
                                    }
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                            Label("Übungsdetails", systemImage: "info.circle")
                        }
                        
                        Divider()
                        
                        if let plan = planExercise.plan, let planExercises = plan.planExercises {
                            let otherExercises = planExercises.filter { $0.id != planExercise.id }.sorted(by: { $0.sortOrder < $1.sortOrder })
                            if !otherExercises.isEmpty {
                                Menu {
                                    Button("Kein Supersatz") {
                                        planExercise.supersetGroup = nil
                                        try? modelContext.save()
                                        onSupersetChanged?()
                                    }
                                    Divider()
                                    let grouped = Dictionary(grouping: otherExercises.filter { $0.supersetGroup != nil }, by: { $0.supersetGroup! })
                                    let standalone = otherExercises.filter { $0.supersetGroup == nil }
                                    
                                    ForEach(Array(grouped.keys.sorted()), id: \.self) { groupId in
                                        if let groupExs = grouped[groupId] {
                                            Section("Supersatz: " + groupExs.compactMap { $0.exercise?.name }.joined(separator: " + ")) {
                                                ForEach(groupExs) { other in
                                                    Button(action: {
                                                        createSuperset(with: other, in: planExercises, plan: plan)
                                                    }) {
                                                        Label(other.exercise?.name ?? "Unbekannt", systemImage: "link")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    if !standalone.isEmpty {
                                        Section("Einzelne Übungen") {
                                            ForEach(standalone) { other in
                                                Button(action: {
                                                    createSuperset(with: other, in: planExercises, plan: plan)
                                                }) {
                                                    Text(other.exercise?.name ?? "Unbekannt")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    if let currentGroup = planExercise.supersetGroup, let linked = otherExercises.first(where: { $0.supersetGroup == currentGroup }) {
                                        Label("Supersatz: \(linked.exercise?.name ?? "Ja")", systemImage: "link")
                                    } else {
                                        Label("Supersatz mit...", systemImage: "link")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            startEditingNotes = true
                            showingNotesSheet = true
                        } label: {
                            Label(planExercise.planSpecificNotes.isEmpty ? "Notiz hinzufügen" : "Notiz bearbeiten", systemImage: "note.text")
                        }
                        
                        Divider()
                        
                        Button {
                            onReorder?()
                        } label: {
                            Label("Übung verschieben", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Übung löschen", systemImage: "trash")
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
            } else {
                HStack {
                    Text("Gelöschte Übung")
                        .font(.headline)
                    Spacer()
                }
            }
            
            if isExpanded {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Sätze")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Sätze", value: $planExercise.targetSets, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        let isCardio = planExercise.exercise?.category.lowercased() == "cardio"
                        
                        VStack(alignment: .leading) {
                            Text(isCardio ? "Zeit (Min)" : "Wdh.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField(isCardio ? "Min" : "Wdh.", value: $planExercise.targetReps, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        let isCardio = planExercise.exercise?.category.lowercased() == "cardio"
                        VStack(alignment: .leading) {
                            Text(isCardio ? "Level" : "Gewicht (kg)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField(isCardio ? "Level" : "Gewicht", value: $planExercise.targetWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Pause (sek)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Pause", value: $planExercise.restDuration, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .alert("Übung löschen", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                if let plan = planExercise.plan {
                    // Clean up supersets if needed
                    if let groupId = planExercise.supersetGroup {
                        let remainingInGroup = plan.planExercises?.filter { $0.id != planExercise.id && $0.supersetGroup == groupId } ?? []
                        if remainingInGroup.count == 1 {
                            remainingInGroup[0].supersetGroup = nil
                        }
                    }
                    plan.planExercises?.removeAll(where: { $0.id == planExercise.id })
                }
                modelContext.delete(planExercise)
                onSupersetChanged?()
            }
        } message: {
            Text("Möchtest du diese Übung wirklich aus dem Plan entfernen?")
        }
        .sheet(isPresented: $showingNotesSheet) {
            PlanExerciseNotesSheet(planExercise: planExercise, isEditing: $startEditingNotes)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func createSuperset(with other: PlanExercise, in planExercises: [PlanExercise], plan: TrainingPlan) {
        let targetGroupId = other.supersetGroup ?? (planExercise.supersetGroup ?? Int.random(in: 1...100000))
        let sourceGroupId = planExercise.supersetGroup
        
        // Update group IDs for all affected exercises
        for ex in planExercises {
            if ex.id == planExercise.id || (sourceGroupId != nil && ex.supersetGroup == sourceGroupId) {
                ex.supersetGroup = targetGroupId
            }
        }
        if other.supersetGroup == nil {
            other.supersetGroup = targetGroupId
        }
        
        var sorted = planExercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        
        // Find all exercises in the new combined group
        let combinedGroup = sorted.filter { $0.supersetGroup == targetGroupId }
        
        // Find the earliest index where any of these exercises appeared
        let earliestIndex = sorted.firstIndex(where: { $0.supersetGroup == targetGroupId }) ?? 0
        
        // Remove all combined group exercises from sorted
        sorted.removeAll(where: { $0.supersetGroup == targetGroupId })
        
        // Insert them all back at earliestIndex to guarantee they are contiguous
        sorted.insert(contentsOf: combinedGroup, at: earliestIndex)
        
        // Reassign sortOrder
        for (i, ex) in sorted.enumerated() {
            ex.sortOrder = i
        }
        
        plan.planExercises = sorted // Force UI update
        try? modelContext.save()
        onSupersetChanged?()
    }
}

struct PlanExerciseHistoryButton: View {
    let exercise: Exercise
    
    @Query private var pastSets: [WorkoutSet]
    @State private var showingHistory = false
    
    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseId = exercise.id
        
        _pastSets = Query(
            filter: #Predicate<WorkoutSet> { set in
                set.exercise?.id == exerciseId && set.isCompleted == true
            },
            sort: \.timestamp, order: .reverse
        )
    }
    
    var body: some View {
        Button(action: { showingHistory = true }) {
            if let lastSet = pastSets.first {
                let isCardio = exercise.category.lowercased() == "cardio"
                Text(isCardio ? "Zuletzt: Lvl \(Int(lastSet.actualWeight)) • \(lastSet.actualReps) Min" : "Zuletzt: \(lastSet.actualWeight, specifier: "%.1f") kg × \(lastSet.actualReps)")
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
        .buttonStyle(.borderless)
        .textCase(nil)
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
        }
    }
}

struct PlanExerciseNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var planExercise: PlanExercise
    @Binding var isEditing: Bool
    @State private var draftNotes = ""

    var body: some View {
        NavigationStack {
            VStack {
                if isEditing {
                    TextEditor(text: $draftNotes)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                } else {
                    ScrollView {
                        Text(planExercise.planSpecificNotes.isEmpty ? "Keine Notizen vorhanden." : planExercise.planSpecificNotes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .navigationTitle("Notiz zur Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing && !planExercise.planSpecificNotes.isEmpty {
                        Button("Abbrechen") { isEditing = false }
                    } else {
                        Button("Schließen") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Speichern") {
                            planExercise.planSpecificNotes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                            try? modelContext.save()
                            isEditing = false
                            if planExercise.planSpecificNotes.isEmpty {
                                dismiss()
                            }
                        }
                    } else {
                        Button("Bearbeiten") {
                            draftNotes = planExercise.planSpecificNotes
                            isEditing = true
                        }
                    }
                }
            }
            .onAppear {
                draftNotes = planExercise.planSpecificNotes
                if draftNotes.isEmpty {
                    isEditing = true
                }
            }
        }
    }
}
