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
                    Text(exercise.category)
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
                
                ExerciseHistoryPreview(exercise: exercise)
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Standard-Pause")
                        .font(.headline)
                    Text("\(Int(exercise.defaultRestDuration)) Sekunden")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Notizen")
                        .font(.headline)
                    if exercise.notes.isEmpty {
                        Text("Keine Notizen hinzugefügt.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(exercise.notes)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(.horizontal)
                
                if let url = exercise.externalVideoURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Video-Tutorial ansehen")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                if !exercise.localMediaPaths.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Bilder")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(exercise.localMediaPaths, id: \.self) { path in
                                    if let image = MediaStorageService.shared.loadImage(named: path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .padding(.top)
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditForm = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(exercise)
                        dismiss()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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

struct ExerciseHistoryPreview: View {
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Historie")
                    .font(.headline)
                Spacer()
                Button(action: { showingHistory = true }) {
                    Text("Mehr")
                        .font(.subheadline)
                        .foregroundColor(.brand)
                }
            }
            
            if pastSets.isEmpty {
                Text("Noch keine Einträge.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(pastSets.prefix(3)) { set in
                    HStack {
                        Text(set.timestamp, format: .dateTime.day().month().year())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(set.actualWeight, specifier: "%.1f") kg × \(set.actualReps)")
                            .font(.subheadline.bold())
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal)
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
        }
    }
}
