import SwiftUI
import SwiftData

struct TrainingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlan.sortOrder) private var plans: [TrainingPlan]
    
    @Binding var triggerAddAlert: Bool
    @State private var showingRenameAlert = false
    @State private var newPlanName = ""
    @State private var planToRename: TrainingPlan? = nil
    
    var body: some View {
        Group {
            if plans.isEmpty {
                ContentUnavailableView(
                    "Keine Trainingspläne",
                    systemImage: "list.clipboard",
                    description: Text("Füge einen neuen Trainingsplan über das '+' oben rechts hinzu.")
                )
            } else {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                            ForEach(plans) { plan in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(plan.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            
                                            Text("\(plan.planExercises?.count ?? 0) Übungen")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Menu {
                                        Button {
                                            planToRename = plan
                                            newPlanName = plan.name
                                            showingRenameAlert = true
                                        } label: {
                                            Label("Umbenennen", systemImage: "pencil")
                                        }
                                        
                                        Button {
                                            duplicate(plan: plan)
                                        } label: {
                                            Label("Duplizieren", systemImage: "doc.on.doc")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            modelContext.delete(plan)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 20)
                                            .padding(.bottom, 20)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .cardStyle()
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Header Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meine Pläne")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(plans.count) Trainingspläne verfügbar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(
                    VStack(spacing: 0) {
                        Color.backgroundPrimary
                        LinearGradient(
                            colors: [Color.backgroundPrimary, Color.backgroundPrimary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 16)
                    }
                    .ignoresSafeArea(.container, edges: .top)
                )
            }
            .background(Color.backgroundPrimary)
            .alert("Neuer Trainingsplan", isPresented: $triggerAddAlert) {
                TextField("Name", text: $newPlanName)
                Button("Abbrechen", role: .cancel) { }
                Button("Erstellen") {
                    createPlan()
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .alert("Plan umbenennen", isPresented: $showingRenameAlert) {
                TextField("Name", text: $newPlanName)
                Button("Abbrechen", role: .cancel) { }
                Button("Speichern") {
                    if let plan = planToRename {
                        plan.name = newPlanName
                    }
                }
                .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
    }
    
    private func createPlan() {
        let plan = TrainingPlan(name: newPlanName, sortOrder: plans.count)
        modelContext.insert(plan)
    }
    
    private func duplicate(plan: TrainingPlan) {
        let newPlan = TrainingPlan(name: "\(plan.name) (Kopie)", sortOrder: plans.count)
        modelContext.insert(newPlan)
        // Copy exercises
        if let exercises = plan.planExercises {
            for (index, planEx) in exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
                let newEx = PlanExercise(
                    sortOrder: index,
                    supersetGroup: planEx.supersetGroup,
                    targetSets: planEx.targetSets,
                    targetReps: planEx.targetReps,
                    targetWeight: planEx.targetWeight,
                    restDuration: planEx.restDuration,
                    plan: newPlan,
                    exercise: planEx.exercise
                )
                modelContext.insert(newEx)
            }
        }
    }
    
    private func movePlan(from source: IndexSet, to destination: Int) {
        var revisedItems = plans
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
    }
}
import SwiftUI

struct TrainingMainView: View {
    @State private var selectedTab = 0
    @State private var isFabExpanded = false
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(WorkoutManager.self) private var workoutManager
    
    @State private var triggerAddPlan = false
    @State private var triggerAddExercise = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $selectedTab) {
                    Text("Pläne").tag(0)
                    Text("Übungen").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.backgroundPrimary)
                
                if selectedTab == 0 {
                    TrainingPlansView(triggerAddAlert: $triggerAddPlan)
                } else {
                    ExerciseLibraryView(triggerAddExercise: $triggerAddExercise)
                }
                
                Spacer(minLength: 0)
            }
            .background(Color.backgroundPrimary)
            .overlay {
                if isFabExpanded {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                        }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 16) {
                    if isFabExpanded {
                        // Neue Übung Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                            selectedTab = 1
                            // Delay slightly to allow tab switch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerAddExercise = true
                            }
                        }) {
                            HStack {
                                Text("Neue Übung")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "dumbbell.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.brand)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        
                        // Neuer Plan Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                            selectedTab = 0
                            // Delay slightly to allow tab switch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerAddPlan = true
                            }
                        }) {
                            HStack {
                                Text("Neuer Plan")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.brandSecondary)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    
                    // Main FAB
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isFabExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.brand)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                            .rotationEffect(.degrees(isFabExpanded ? 45 : 0))
                    }
                }
                .padding(.bottom, workoutManager.isWorkoutActive ? 80 : 20)
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
        }
    }
}
