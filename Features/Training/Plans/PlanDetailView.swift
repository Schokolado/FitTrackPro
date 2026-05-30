import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: TrainingPlan
    
    @State private var showingExerciseSelection = false
    @State private var showingEditNameAlert = false
    @State private var editName = ""
    
    var body: some View {
        List {
            let sortedExercises = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
            
            ForEach(sortedExercises) { planEx in
                PlanExerciseRowView(planExercise: planEx)
            }
            .onMove(perform: moveExercises)
            .onDelete(perform: deleteExercises)
            
            Section {
                Button(action: { showingExerciseSelection = true }) {
                    Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.brand)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        editName = plan.name
                        showingEditNameAlert = true
                    }) {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis.circle")
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
        .sheet(isPresented: $showingExerciseSelection) {
            NavigationStack {
                ExerciseSelectionView(plan: plan)
            }
        }
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var revisedItems = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = index
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        let sorted = (plan.planExercises ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
        for index in offsets {
            let item = sorted[index]
            modelContext.delete(item)
        }
    }
}
