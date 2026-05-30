import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var planExercise: PlanExercise
    var onReorder: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let exercise = planExercise.exercise {
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
                    
                    Menu {
                        Button {
                            onReorder?()
                        } label: {
                            Label("Übung verschieben", systemImage: "arrow.up.arrow.down")
                        }
                        
                        if let plan = planExercise.plan, let planExercises = plan.planExercises {
                            let otherExercises = planExercises.filter { $0.id != planExercise.id }.sorted(by: { $0.sortOrder < $1.sortOrder })
                            if !otherExercises.isEmpty {
                                Menu {
                                    Button("Kein Supersatz") {
                                        planExercise.supersetGroup = nil
                                    }
                                    Divider()
                                    ForEach(otherExercises) { other in
                                        Button(other.exercise?.name ?? "Unbekannt") {
                                            let newGroupId = other.supersetGroup ?? (planExercise.supersetGroup ?? Int.random(in: 1...100000))
                                            planExercise.supersetGroup = newGroupId
                                            other.supersetGroup = newGroupId
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
                        
                        Button(role: .destructive) {
                            if let plan = planExercise.plan {
                                plan.planExercises?.removeAll(where: { $0.id == planExercise.id })
                            }
                            modelContext.delete(planExercise)
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
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Sätze")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Sätze", value: $planExercise.targetSets, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading) {
                    Text("Wdh.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Wdh.", value: $planExercise.targetReps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Gewicht (kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", value: $planExercise.targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading) {
                    Text("Pause (s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Pause", value: $planExercise.restDuration, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            

        }
        .padding(.vertical, 4)
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
        .buttonStyle(.borderless)
        .textCase(nil)
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
        }
    }
}
