import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingEditForm = false
    @State private var showingFullScreenViewer = false
    @State private var selectedImageIndex: Int = 0
    
    private var categoryIcon: String {
        switch exercise.category.lowercased() {
        case "brust": return "figure.strengthtraining.traditional"
        case "rücken": return "figure.core.training"
        case "beine": return "figure.run"
        case "schultern": return "figure.cross.training"
        case "arme": return "figure.mind.and.body"
        case "bauch": return "figure.pilates"
        case "cardio": return "heart.fill"
        case "ganzkörper": return "figure.highintensity.intervaltraining"
        default: return "dumbbell.fill"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(exercise.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 14))
                        Text(exercise.category.uppercased())
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.color(for: exercise.category).opacity(0.15))
                    .foregroundColor(themeManager.color(for: exercise.category))
                    .clipShape(Capsule())
                    
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
                
                if exercise.notes.isEmpty {
                    Button(action: { showingEditForm = true }) {
                        HStack {
                            Image(systemName: "note.text.badge.plus")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Notizen hinzufügen")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Notizen")
                            .font(.headline)
                        Text(exercise.notes)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                if let url = exercise.externalVideoURL {
                    Button(action: { openVideoURL(url) }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Video-Tutorial ansehen")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    Button(action: { showingEditForm = true }) {
                        HStack {
                            Image(systemName: "video.badge.plus")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Video-Tutorial hinzufügen")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Bilder")
                        .font(.headline)
                        .padding(.horizontal)
                        
                    if !exercise.localMediaPaths.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(Array(exercise.localMediaPaths.enumerated()), id: \.offset) { index, path in
                                    if let image = MediaStorageService.shared.loadImage(named: path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture {
                                                selectedImageIndex = index
                                                showingFullScreenViewer = true
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Button(action: { showingEditForm = true }) {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Bilder hinzufügen")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .padding(.horizontal)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom)
            }
            .padding(.top)
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
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
        .fullScreenCover(isPresented: $showingFullScreenViewer) {
            FullScreenImageViewer(mediaPaths: exercise.localMediaPaths, initialIndex: selectedImageIndex)
        }
    }
    
    private func openVideoURL(_ url: URL) {
        var appURL: URL? = nil
        let urlString = url.absoluteString
        
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            let schemeReplaced = urlString
                .replacingOccurrences(of: "https://", with: "youtube://")
                .replacingOccurrences(of: "http://", with: "youtube://")
            
            if urlString.contains("youtu.be/") {
                if let id = urlString.components(separatedBy: "youtu.be/").last {
                    appURL = URL(string: "youtube://watch?v=\(id)")
                }
            } else {
                appURL = URL(string: schemeReplaced)
            }
        }
        
        if let appURL = appURL {
            UIApplication.shared.open(appURL, options: [:]) { success in
                if !success {
                    // Fallback to web browser if YouTube app is not installed
                    UIApplication.shared.open(url)
                }
            }
        } else {
            UIApplication.shared.open(url)
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
                        Spacer()
                        let isCardio = exercise.category.lowercased() == "cardio"
                        Text(isCardio ? "Lvl \(Int(set.actualWeight)) • \(set.actualReps) Min" : "\(set.actualWeight, specifier: "%.1f") kg × \(set.actualReps)")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
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
