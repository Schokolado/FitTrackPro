import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    
    @State private var showingEditForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                
                HStack {
                    Text(exercise.category.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandSecondary.opacity(0.2))
                        .foregroundColor(.brand)
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    if exercise.isCustom {
                        Text("Eigene Übung")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Standard-Pause")
                        .font(.headline)
                    Text("\(Int(exercise.defaultRestDuration)) Sekunden")
                        .foregroundColor(.secondary)
                }
                .cardStyle()
                .padding(.horizontal)
                
                if !exercise.notes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Notizen")
                            .font(.headline)
                        Text(exercise.notes)
                            .foregroundColor(.secondary)
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                // Placeholder für Video/Bilder Upload
                VStack(alignment: .center, spacing: Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Bilder / Videos hinzufügen (Milestone 2.1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()
                .padding()
            }
            .padding(.top)
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                ExerciseFormView(exerciseToEdit: exercise)
            }
        }
    }
}
