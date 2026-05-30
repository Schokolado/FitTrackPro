import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var planExercise: PlanExercise
    var onReorder: (() -> Void)? = nil
    var onSupersetChanged: (() -> Void)? = nil
    @State private var isExpanded: Bool = false
    
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
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundColor(.brand)
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
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
                        
                        Button {
                            onReorder?()
                        } label: {
                            Label("Übung verschieben", systemImage: "arrow.up.arrow.down")
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
                            TextField("Gewicht", value: $planExercise.targetWeight, format: .number)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
